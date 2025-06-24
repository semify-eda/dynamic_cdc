/**
* Module: testbench.sv
*
* Description:
*   Top-level testbench for the Dynamic CDC model. It provides a basic simulation environment
*   to demonstrate the functionality of the model and compare the behavior of the dynamic
*   CDC model with a synthesizable synchronizer. Provides counters for the {1,2,3} cycle
*   delays inserted.
*/
`default_nettype none
module testbench;

  localparam halfperiod_src = 8ns;
  localparam halfperiod_dst = 5ns;
  localparam random_inputs  = 1;

  bit clk_src;
  bit clk_dst;
  bit rst;
  bit din;

  logic out_dcdc;
  logic out_sim;
  bit   timeout;

  int edges_i     = 0;
  int edges_dcdc  = 0;
  int edges_sim   = 0;

  event d_1cyc;
  event d_2cyc;
  event d_3cyc;
  int   delays_1cycle = 0;
  int   delays_2cycle = 0;
  int   delays_3cycle = 0;

  bit [4:1] latency_monitor;

  always #halfperiod_src  clk_src = ~clk_src;
  always #halfperiod_dst  clk_dst = ~clk_dst;

  initial begin $dumpfile("waves.vcd"); $dumpvars; end

  //****************************************************************************
  //* DUTs
  //****************************************************************************
  sync_2dff dcdc_sync_2dff (
    .clk_i            (clk_dst  ),
    .d_i              (din      ),
    .rstn_i           (rst      ),
    .q_o              (out_dcdc )
  );

  sync_2dff #(
    .SYNTHESIS        (1        )
  ) sim_sync_2dff (
    .clk_i            (clk_dst  ),
    .d_i              (din      ),
    .rstn_i           (rst      ),
    .q_o              (out_sim  )
  );


  initial begin : test_sequence
    repeat(2) @(posedge clk_src);
    rst = '1;
    timeout = '1;

    // insert a glitch
    #2;
    din = '1;
    #1;
    din = '0;
    #1;
    din = '1;
    #1;
    din = '0;
    #1

    repeat(5) @(posedge clk_src);

    timeout = '0;
    repeat (100) @(posedge clk_src);
    timeout = '1;

    // keep din stable at the end of simulation for edge checks
    repeat (10) @(posedge clk_src);

    $finish();
  end : test_sequence

  always @(posedge clk_src) begin : input_generation
    if      (timeout)       din = '0;
    else if (random_inputs) din = (~rst) ? '0 : logic'($random);
    else                    din = (~rst) ? '0 : ~din;
  end : input_generation

  //****************************************************************************
  //* Distribution of synchronization latencies
  //****************************************************************************
  always @(posedge clk_dst) latency_monitor[4:1] <= {latency_monitor[3:1], din};

  always @(out_dcdc) begin
    if((out_dcdc == latency_monitor[1]) & (latency_monitor[1] ^ latency_monitor[2]))
      -> d_1cyc;
    if((out_dcdc == latency_monitor[2]) & (latency_monitor[2] ^ latency_monitor[3]))
      -> d_2cyc;
    if((out_dcdc == latency_monitor[3]) & (latency_monitor[3] ^ latency_monitor[4]))
      -> d_3cyc;
  end

  always @(d_1cyc   ) delays_1cycle += 1;
  always @(d_2cyc   ) delays_2cycle += 1;
  always @(d_3cyc   ) delays_3cycle += 1;
  always @(din      ) edges_i       += 1;
  always @(out_dcdc ) edges_dcdc    += 1;
  always @(out_sim  ) edges_sim     += 1;

endmodule
`default_nettype wire
