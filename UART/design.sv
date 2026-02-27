module uart_tx
  #(parameter clk_frequency = 1000000,
   parameter baud_rate = 9600)(
input clk, rst, newd,
  input [7:0] data_in,
  output reg tx, 
  output reg done_tx);
  
  localparam clkcount = (clk_frequency/baud_rate);
  
  integer count;
  integer countd = 0;
  reg uclk = 0;
  reg uclk_en = 0;
  
  typedef enum bit [1:0] {idle = 2'b00, start = 2'b01, transfer = 2'b10, stop = 2'b11} state_type;
 
  state_type state;
  
  ////uclk generation /////////////////////////////////
  
  always @(posedge clk) begin
    if(rst) begin
    	count <= 0;
      uclk <= 0;
      uclk_en <= 0;
    end
    else if(count == clkcount/2) begin
      count <= 0;
    uclk <= ~uclk;		// generated clock for peripherals
    uclk_en <= 1;
    end
    else
      begin
      count <= count + 1;
      uclk_en <= 0;
      end
  end
///////////////////////////////////////////////////////  
  reg [7:0] din;
  
  always @(posedge clk) begin
    tx <= 1;
    state <= idle;
    if(rst) begin
      din <= 0;
      tx <= 1;
      done_tx <= 0;
      uclk <= 0;
      state = idle;
    end
    else if(uclk_en) begin
      case(state)
      idle: begin
      	done_tx <= 0;
        tx <= 1;
        if(newd == 1)
          state <= start;
        else
          state <= idle;
      end
      start:begin
      	din <= data_in;
        tx <= 0;
        state <= transfer;
      end
      transfer:begin
        if(countd < 8) begin
          tx <= din[countd];
          countd <= countd + 1;
          state <= transfer;
        end
        else
          begin
          	countd <= 0;
            state <= stop;
          end
      end
      stop:begin
      	done_tx <= 1;
        tx <= 1;
        state <= idle;
        countd <= 0;
        state <= idle;
      end
        default: state <= stop;
      endcase
    end
  end
endmodule
  
module uart_rx #(parameter clk_frequency = 1000000,
                   baud_rate = 9600)(
  input clk, rst, rx,
  output reg done,
  output reg [7:0] rxdata);
    
      
  localparam clkcount = (clk_frequency/baud_rate);
  
  integer count;
  integer countd = 0;
  reg uclk = 0;
  reg uclk_en = 0;
////uclk generation /////////////////////////////////  
  always @(posedge clk) begin
    if(rst) begin
    	count <= 0;
      uclk <= 0;
      uclk_en <= 0;
    end
    else if(count == clkcount/2) begin
      count <= 0;
    uclk <= ~uclk;		// generated clock for peripherals
    uclk_en <= 1;
    end
    else
      begin
      count <= count + 1;
      uclk_en <= 0;
      end
  end
///////////////////////////////////////////////////////  

typedef enum bit [1:0]{idle = 2'b00, start = 2'b01, transfer = 2'b10, stop = 2'b11} state_type;
state_type state;
   
    reg [7:0] tx_data;
    
    always @(posedge clk) begin
      if(rst)begin
      done <= 0;
      uclk <= 0;
      state = idle;
      end
      else if(uclk_en) begin
        case(state)
        idle:begin
        	done <= 0;
          	rxdata <= 0;
          if(rx == 0)
            state <= start;
          else
            state <= idle;
        end
          start:begin
         	state <= transfer;
          end
          transfer:begin
            if(countd < 8) begin
            tx_data <= {rx, tx_data[7:1]};
            countd <= countd + 1;
            state <= transfer;
            end
            else begin
            countd <= 0;
            state <= stop;
            end
          end
          stop: begin
          done <= 1;
          rxdata <= tx_data;
          state <= idle;
          end
          default: state <= idle;
        endcase
      end
    end   
endmodule

module uart_top
#(
parameter clk_freq = 1000000,
parameter baud_rate = 9600
)
(
  input clk,rst, 
  input rx,
  input [7:0] dintx,
  input newd,
  output tx, 
  output [7:0] doutrx,
  output donetx,
  output donerx
    );
    
uart_tx 
#(clk_freq, baud_rate) 
utx   
(clk, rst, newd, dintx, tx, donetx);   

uart_rx 
#(clk_freq, baud_rate)
rtx
(clk, rst, rx, donerx, doutrx);    
    
    
endmodule
