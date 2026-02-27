class transaction;

  typedef enum bit {write = 1'b0, read = 1'b1} oper_type;
  // write --> master transmitting data;
  // read --> master receiving data;
  randc oper_type oper;
  bit rx;
  rand bit [7:0] dintx;
  bit newd;
  bit tx;
  bit [7:0] doutrx;
  bit donetx;
  bit donerx;
  
  function transaction copy();
    copy = new();
    copy.rx = this.rx;
    copy.dintx = this.dintx;
    copy.newd = this.newd;
    copy.tx = this.tx;
    copy.doutrx = this.doutrx;
    copy.donetx = this.donetx;
    copy.donerx = this.donerx;
    copy.oper = this.oper;
  endfunction
  
endclass

class generator;

  transaction tra;
  mailbox #(transaction) mbx;
  event done; /// to specify randomization is completed or not
  
  int count = 0;  // specify no. of transaction packets to be send
  
  event drvnext;
  event sconext;
  
  function new(mailbox #(transaction) mbx);
  this.mbx = mbx;
    tra = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tra.randomize) else $error("[GEN]: RANDOMIZATION FAILED");
      mbx.put(tra.copy);
      $display("[GEN]: Oper: %0s Din: %0d", tra.oper.name(), tra.dintx);
      @(drvnext);		/// waiting till driver completes its task
      @(sconext);
    end
    ->done;
  endtask
  
endclass

class driver;

  virtual uart_if uif;
  transaction tra;
  mailbox #(transaction) mbx;		/// communication b/w generator and driver and then with DUT
  mailbox #(bit [7:0]) mbxds;		/// communication b/w driver and scoreboard
  
  event drvnext;
  bit [7:0] din;
  
  bit wr = 0; //// random operation read/write
  bit [7:0] datarx; // data received during read
  
  function new(mailbox #(bit [7:0]) mbxds, mailbox #(transaction) mbx);
  this.mbx = mbx;
    this.mbxds = mbxds;
  endfunction
  
  task reset();
  uif.rst <= 1'b1;		//// driver talking to DUT via interface
    uif.dintx <= 0;
    uif.newd <= 0;
    uif.rx <= 1'b1;
    
    repeat(5) @(posedge uif.uclktx);
    uif.rst <= 1'b0;
    @(posedge uif.uclktx);
    $display("[DRV]: RESET DONE");
    $display("---------------------------------");
  endtask
  
  task run();
  forever begin
    mbx.get(tra);	// getting randomize transaction packet
    if(tra.oper == 1'b0)	// data transmission
      begin
        @(posedge uif.uclktx);
        uif.rst <= 1'b0;
        uif.newd <= 1'b1;
        uif.rx <= 1'b1;
        uif.dintx <= tra.dintx;  /// sending data to DUT via interface
        @(posedge uif.uclktx);
        uif.newd <= 1'b0;
        
        /// waiting for completion
       // repeat(9) @(posedge uif.utx.uclk_en);
        mbxds.put(tra.dintx);
        $display("[DRV]: Data Sent: %0d", tra.dintx);
        wait(uif.donetx == 1'b1);
        ->drvnext;
      end
    else if(tra.oper == 1'b1)
      begin
        @(posedge uif.uclkrx);
        uif.rst <= 1'b0;
        uif.rx <= 1'b0;
        uif.newd <= 1'b0;
        @(posedge uif.uclkrx);
        
        for(int i=0;i<=7;i++)
          begin
            @(posedge uif.uclkrx);
            uif.rx <= $urandom_range(0,1);		//// Driver stimulating the RX pin, acting like external UART transmitter
            datarx[i] = uif.rx;
          end
        mbxds.put(datarx);
        $display("[DRV]: Data RCVD: %0d", datarx);
        wait(uif.donerx == 1'b1);
        uif.rx <= 1'b1;
        ->drvnext;
      end
  end
  endtask
endclass

class monitor;

  transaction tra;
  
  mailbox #(bit [7:0]) mbx;
  
  bit [7:0] srx; // send
  bit [7:0] rrx; // recvd
  
  virtual uart_if uif;
  
  function new(mailbox #(bit [7:0]) mbx);
    this.mbx = mbx;
  endfunction
  
  task run();
  forever begin
    @(posedge uif.uclktx);
    if((uif.newd == 1'b1) && (uif.rx == 1'b1))
      begin
        @(posedge uif.uclktx); // start collecting tx data from next clock tick
        
        for(int i=0;i<=7;i++) begin
          @(posedge uif.uclktx);
          srx[i] = uif.tx;
        end
        $display("[MON]: DATA SEND on UART TX: %0d", srx);
        @(posedge uif.uclktx);
        mbx.put(srx);
      end
    else if((uif.rx == 1'b0) && (uif.newd == 1'b0))
      begin
        wait(uif.donerx == 1);
        rrx = uif.doutrx;
        $display("[MON]: DATA RCVD RX: %0d", rrx);
        @(posedge uif.uclktx);
        mbx.put(rrx);
      end
  end
  endtask
  
endclass

class scoreboard;
  mailbox #(bit [7:0]) mbxds, mbxms;
  
  bit [7:0] ds;
  bit [7:0] ms;
  
  event sconext;
  
  function new(mailbox #(bit [7:0]) mbxds, mailbox #(bit [7:0]) mbxms);
    this.mbxds = mbxds;
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin
    
      mbxds.get(ds);
      mbxms.get(ms);
      
      $display("[SCO]: DRV: %0d MON: %0d", ds, ms);
      if(ds == ms)
        $display("DATA MATCHED");
      else
        $display("DATA MISATCHED");
      
      $display("-------------------------------------");
      ->sconext;
    end
  endtask
endclass

class environment;

  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd; // gen -> drv
  event nextgs; // gen -> sco
  
  mailbox #(transaction) mbxgd; // gen - drv
  mailbox #(bit [7:0]) mbxds; /// drv - sco
  mailbox #(bit [7:0]) mbxms; /// mon - sco
  
  virtual uart_if uif;
  
  function new(virtual uart_if uif);
    mbxgd = new();
    mbxms = new();
    mbxds = new();
    
    gen = new(mbxgd);
    drv = new(mbxds, mbxgd);
    mon = new(mbxms);
    sco = new(mbxds, mbxms);
    
    this.uif = uif;
    drv.uif = this.uif;
    mon.uif = this.uif;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_none
  endtask
  
  task post_test();
    @gen.done;
    #100;
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  
  uart_if uif();
  
  uart_top #(1000000,9600) dut(uif.clk, uif.rst, uif.rx, uif.dintx, uif.newd, uif.tx, uif.doutrx, uif.donetx, uif.donerx);
  
  initial begin
    uif.clk <= 0;
  end
  
  always #10 uif.clk <= ~uif.clk;
  
  environment env;
  initial begin
    env = new(uif);
    env.gen.count = 5;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
  assign uif.uclktx = dut.utx.uclk;
  assign uif.uclkrx = dut.rtx.uclk;
endmodule

interface uart_if;
  logic clk;
  logic rst;
  logic rx;
  logic [7:0] dintx;
  logic newd;
  logic tx;
  logic [7:0] doutrx;
  logic donetx;
  logic donerx;
  logic uclktx;
  logic uclkrx;
endinterface
