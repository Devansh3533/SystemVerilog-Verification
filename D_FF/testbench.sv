class transaction;
  
  rand bit din;
  bit dout;
  
  function transaction copy();
    copy =new();
    copy.din = this.din;
    copy.dout = this.dout;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] : DIN : %0b DOUT: %0b",tag,din,dout);
    endfunction
  
endclass
//////////////////////////////////////////////////////////////////////////////////

class generator;
  transaction tr;
  mailbox #(transaction) mbx;  /// send data to driver
  mailbox #(transaction) mbxref; /// send data to scoreboard (reference data)
  
  event sconext; /// sense completion of scoreboard work
  event done;   /// Triggered when requested number of stimulus is completed
  int count;   /// stimulus count
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
  this.mbx = mbx;
  this.mbxref = mbxref;
  tr = new();
  endfunction

  task run();
    repeat (count) begin
      assert(tr.randomize) else $error("[GEN]: RANDOMIZATION FAILED"); /// randomize the transaction
      mbx.put(tr.copy); 	// to send deep copy of tr class to driver class
      mbxref.put(tr.copy); 	// to send deep copy of tr class to scoreboard
      tr.display("GEN");	// "GEN" is specified Tag
      @(sconext);			// wait for scoreboard to complete the process of comparison
    end
    ->done;		// triggering done event
  endtask

endclass
//////////////////////////////////////////////////////////////////////////////////////////////////////////

class driver;

  transaction tr;		// creating transaction handle tr
  mailbox #(transaction) mbx;		// declaring mailbox handle mbx
  virtual dff_if vif;		//// vif is handle to an interface, not physical instance
  
  function new(mailbox #(transaction) mbx);		// custom contructor
    this.mbx = mbx;								// indicates mailbox working b/w generator and driver
  endfunction
  
  task reset();			// performing reset of DUT
  vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 1'b0;
    @(posedge vif.clk);
    $display("[DRV]: RESET DONE");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);		// allow to receive data from generator
      vif.din <= tr.din;
      @(posedge vif.clk);
      tr.display("DRV");
      vif.din <= 1'b0;
      @(posedge vif.clk);
    end
  endtask
  
endclass
//////////////////////////////////////////////////////////////////////////////////////////////////////////

/* A monitor class observes DUT signals, converts them into transaction objects, and sends them to other components (like a scoreboard or reference model) without driving anything. */

class monitor;
transaction tr;
  mailbox #(transaction) mbx;
  virtual dff_if vif;
  
  function new(mailbox #(transaction) mbx);
  this.mbx = mbx;					//// creating and adding these mailbox threads in common mailbox group
  endfunction
  
  task run();
    tr = new();
    forever begin
      repeat(2) @(posedge vif.clk);	// why 2 clk. because in driver, signal generation takes 2 clk signals
      tr.dout = vif.dout; // monitor is only sampling a value that is already stable on the interface.
      /// that's why blocking assignment
      mbx.put(tr);
      tr.display("MON");
    end
  endtask
  
endclass
///////////////////////////////////////////////////////////////////////////////////////////////////////////

class scoreboard;
  
  transaction tr;
  transaction trref;
  
  mailbox #(transaction) mbx;		//	two transactions for comparison
  mailbox #(transaction) mbxref;
  event sconext;
  
  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;
    this.mbxref = mbxref;
  endfunction
 
  task run();
    forever begin
      mbx.get(tr);	// from monitor class
      mbxref.get(trref);  // from generator class
      tr.display("SCO");
      trref.display("REF");
      
      if(tr.dout == trref.din)
        $display("[SCO]: DATA MATCHED");
      else
        $display("[SCO]: DATA MISMATCHED");
      
      $display("--------------------------------------------------");
      ->sconext;
    end
  endtask
  
endclass
//////////////////////////////////////////////////////////////////////////////////////////////////////

class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event next;		/// gen -> sco
  
  mailbox #(transaction) gdmbx;		// mailbox working b/w gen - drv
  
  mailbox #(transaction) msmbx;		/// mon - sco
  
  mailbox #(transaction) mbxref;	// gen - sco
  
  virtual dff_if vif;
  
  function new(virtual dff_if vif);
    
    gdmbx = new();
    mbxref = new();
    
    gen = new(gdmbx, mbxref);
    drv = new(gdmbx);
    
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx, mbxref);
    
    
    /// connecting interface handles (just like plugging wires)
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    /// Event connections (syncronization)
    gen.sconext = next;
    sco.sconext = next;
    
  endfunction
  
  // reset task
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass
/////////////////////////////////////////////////////////////////////////////////////////////////////////

module tb;
  
  dff_if vif();		/// interface instance
  
  D_FF dut(vif);
  
  initial begin
  vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 30;			/// specifying number of count
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");		/// system tasks to display waveform
    $dumpvars;
  end
endmodule
