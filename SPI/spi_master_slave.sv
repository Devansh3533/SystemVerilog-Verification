module SPI(
input clk, newd, rst,
input [11:0] din,
output reg cs, MOSI, sclk);
  
  typedef enum bit [2:0] {idle = 3'b000, enable = 3'b001,load = 3'b010, send = 3'b011, comp = 3'b100} state_type;
  
  state_type state = idle;
  
  int countc = 0;
  int count = 0;
  
  /////////////////////// sclk generation ///////////////////
  
  logic sclk_d;
  wire sclk_posedge;
  reg sclk_tick;
  
  always @(posedge clk) begin
    if(rst == 1) begin
      countc <= 0;
      sclk <= 1'b0;
      sclk_tick <= 0;
    end
    else begin
      if(countc == 9) begin
        countc <= 0;
        sclk <= ~sclk;
        sclk_tick <= 1'b1;
        end
      else
        countc <= countc + 1;
      sclk_tick <= 0;
      end
  end
  
  always @(posedge clk) begin
    if(rst)
      sclk_d <= 1'b0;
    else
      sclk_d <= sclk;
  end
  assign sclk_posedge = sclk & ~sclk_d;

////////////////////////////////////////////////////
  
  //// using sclk for data transmission
  
  reg [11:0] temp;
  
  always @(posedge clk) begin
    if(rst == 1'b1) begin
      cs <= 1'b1;
      MOSI <= 1'b0;
      count <= 0;
    end
    else if(sclk_tick) begin
    case(state)
      idle: begin
      		temp <= 12'h000;
        	cs <= 1'b1;
        MOSI = 1'b0;
        count <= 0;
        if(newd == 1'b1) begin
          state <= enable;
        end
        else
          state <= idle;
      end
      enable:begin
        cs <= 1'b0;
        temp <= din;
        state <= load;
      end
      load : state <= send;
      send:begin
        if(count<12) begin
          MOSI = temp[count];
          count <= count + 1'b1;
          state <= send;
        end
        else
          begin
          	count <= 0;
            state <= comp;
          end
      end
      comp: begin
        state <= idle;
      end
      default: state <= idle;
    endcase
    end
  end
endmodule

interface spi_if;
  logic clk, newd, rst;
  logic [11:0] din;
  logic [11:0] dout;
  logic done;
  logic sclk;
 // logic cs, MOSI, sclk;
endinterface

module SPI_Slave (input sclk, MOSI, cs,
                 output reg done,
                  output [11:0] data_out);
  
  typedef enum bit {detect_start = 1'b0, read_data = 1'b1} state_type;
  
  state_type state = detect_start;
  reg [11:0] temp = 12'd0;
  
  int count = 0;
  
  always @(posedge sclk) begin
    case(state)
      detect_start: begin
      done <= 1'b0;
        if(cs == 1'b0)
          state <= read_data;
        else
          state <= detect_start;
      end
	 read_data:begin
  		temp <= {MOSI, temp[11:1]};
  		count = count + 1;
  		if(count == 11) begin
    		done <= 1;
  			count <= 0;
    		state <= detect_start;
      		end
		end
  	 default: state <= detect_start;
     endcase
end  

assign data_out = temp;

endmodule

module top(input clk, newd, rst, 
           input [11:0] din,
          output done,
           output reg [11:0] dout);
  wire cs, sclk, mosi;
  
  SPI m1(clk, newd, rst, din, cs,mosi, sclk);
  SPI_Slave m2(sclk, mosi, cs, done, dout);
  
endmodule
