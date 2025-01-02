// Code your testbench here
// or browse Examples
class transaction;
  rand bit oper;
  bit [7:0] data_in;
  bit wr_ena, rd_ena;
  bit full,empty;
  bit [7:0] data_out;
  
    constraint oper_ctrl {  
    oper dist {1 :/ 50 , 0 :/ 50}; 
  }
  
endclass

class generator;
  mailbox #(transaction) mbx;
  transaction tr;
  event next;
  event done;
  int count=0;
  int i=0;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
    tr=new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize()) else
        $display("randomization failed");
      i++;
      mbx.put(tr);
      $display("[GEN] : opertaion: %0d, iteration: %0d",tr.oper, i);
      @(next);
      
    end
      -> done;
  endtask
endclass

class driver;
  transaction data;
  mailbox #(transaction) mbx;
  virtual fifo_inf inf;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction
  
  task reset();
    inf.rst<=1'b1;
    inf.wr_ena<=1'b0;
    inf.rd_ena<=1'b0;
    inf.data_in<=8'b0;
    repeat(5)@(posedge inf.clk);
    inf.rst<=1'b0;
    $display("[DRV]: Reset Done");
    $display("-------------------------------------------");
  endtask
  
  task write();
    @(posedge inf.clk);
     inf.rst<=1'b0;
    inf.wr_ena<=1'b1;
    inf.rd_ena<=1'b0;
    inf.data_in<=$urandom_range(1,10);
    @(posedge inf.clk);
    inf.wr_ena<=1'b0;
    $display("[DRV]: data_in: %0d", inf.data_in);
    @(posedge inf.clk);
  endtask
  
  task read();
    @(posedge inf.clk);
    inf.rst<=1'b0;
    inf.wr_ena<=1'b0;
    inf.rd_ena<=1'b1;
    @(posedge inf.clk);
    inf.rd_ena<=1'b0;
    $display("[DRV]: Data Read");
    @(posedge inf.clk);
  endtask
  
  task run();
    forever begin
      mbx.get(data);
      if(data.oper==1) write();
      else read();
    end
  endtask
endclass

class monitor;
  mailbox #(transaction) mbx;
  transaction tr;
  virtual fifo_inf inf;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
     tr=new();
    forever begin
      repeat(2) @(posedge inf.clk);
      tr.wr_ena=inf.wr_ena;
      tr.rd_ena=inf.rd_ena;
      tr.full=inf.full;
      tr.empty=inf.empty;
      tr.data_in=inf.data_in;
      @(posedge inf.clk);
      tr.data_out=inf.data_out;
      mbx.put(tr);
      $display("[MON]: wr_ena: %0d, rd_ena: %0d, full: %0d, empty: %0d, data_in: %0d, data_out:%0d", inf.wr_ena, inf.rd_ena, inf.full, inf.empty, inf.data_in, inf.data_out);
    end
  endtask
endclass


class scoreboard;
  mailbox #(transaction) mbx;
  transaction tr;
  event next;
  bit [7:0] din[$];
  bit [7:0] temp;
  int err=0;
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      
      if(tr.wr_ena==1'b1) begin
        if(tr.full==1'b0) begin
          din.push_front(tr.data_in);
          $display("[SCO] : DATA STORED IN QUEUE :%0d", tr.data_in);
        end
        else begin
          $display("[SCO]:FIFO is FULL");
        end
        $display("-----------------------------------");
      end
      
      if(tr.rd_ena==1'b1)
        begin
          if(tr.empty==1'b0)
            begin
              temp=din.pop_back();
              if(tr.data_out==temp) $display("[SCO]:DATA MATCHED");
              else begin
                $display("[SCO]: ERROR DATA MISMATCHED");
                err++;
              end
            end
          else $display("[SCO]: FIFO is EMPTY");
          $display("---------------------------------------");
        end
      -> next;
    end
  endtask
endclass

class environment;
   generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;  // Generator + Driver mailbox
  mailbox #(transaction) msmbx;  // Monitor + Scoreboard mailbox
  event nextgs;
  virtual fifo_inf inf;
  
  function new(virtual fifo_inf inf);
    gdmbx=new();
    msmbx=new();
    gen=new(gdmbx);
    drv=new(gdmbx);
    mon=new(msmbx);
    sco=new(msmbx);
    
    this.inf=inf;
    drv.inf=this.inf;
    mon.inf=this.inf;
    gen.next=nextgs;
    sco.next=nextgs;
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
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $display("---------------------------------------------");
    $display("Error Count :%0d", sco.err);
    $display("---------------------------------------------");
    $finish();
  endtask
  
   task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb();
  fifo_inf inf();
  syn_fifo DUT(inf.clk, inf.rst, inf.data_in, inf.wr_ena, inf.rd_ena, inf.full, inf.empty, inf.data_out);
  
    initial begin
    inf.clk <= 0;
  end
    
  always #10 inf.clk <= ~inf.clk;
    
  environment env;
    
  initial begin
    env = new(inf);
    env.gen.count = 10;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
