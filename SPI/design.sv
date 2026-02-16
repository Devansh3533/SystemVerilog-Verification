module SPI(
input clk, newd, rst,
input [11:0] din,
output reg cs, MOSI, sclk);
  
  typedef enum bit [1:0] {idle = 2'b00, enable = 2'b01, send = 2'b10, comp = 2'b11} state_type;
  
  state_type state = idle;
  
  int countc = 0;
  int count = 0;
  
  /////////////////////// sclk generation ///////////////////
  
  always @(posedge clk) begin
    if(rst == 1) begin
      countc <= 0;
      sclk <= 1'b0;
    end
    else if(countc < 10) begin
        countc <= countc + 1;
        end
    else
      begin
      countc <= 0;
        sclk = ~sclk;
      end
  end

  //// using sclk for data transmission
  
  reg [11:0] temp;
  
  always @(posedge sclk) begin
    if(rst == 1'b1) begin
      cs <= 1'b1;
      MOSI <= 1'b0;
    end
    else begin
    case(state)
      idle: begin
      		temp <= 8'h00;
        	cs <= 1'b1;
        MOSI = 1'b0;
        if(newd == 1'b1) begin
          state <= enable;
        end
        else
          state <= idle;
      end
      enable:begin
        cs <= 1'b0;
        temp <= din;
        state <= send;
      end
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
  logic cs, MOSI, sclk;
endinterface
