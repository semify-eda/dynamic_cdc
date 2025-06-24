/**
* Module: benchmark_tb.sv
*
* Description:
*   Testbench to measure the performance impact of enabling different features
*   the dynamic CDC model such as synthesis-friendly modeling, assertions, and glitch monitoring.
*   Tests simulation time for 64 synchronizers for 10,000,000 clock cycles.
*/
module benchmark_tb;

  localparam halfperiod_src = 8ns;
  localparam halfperiod_dst = 5ns;
  localparam random_inputs  = 1;

  bit clk_src;
  bit clk_dst;
  bit rstn;

  bit   [63:0] din;
  logic [63:0] dout;

  always #halfperiod_src  clk_src = ~clk_src;
  always #halfperiod_dst  clk_dst = ~clk_dst;

  always @(posedge clk_src) begin
    din = {{32'($urandom())}, {32'($urandom())}};
  end

  parameter SYNTHESIS             = 0;
  parameter ENABLE_GLITCH_MONITOR = 0;

  // 64 synchronizers
  sync_2dff #(
    .SYNTHESIS              (1'(SYNTHESIS)            ),
    .ENABLE_GLITCH_MONITOR  (1'(ENABLE_GLITCH_MONITOR))
  ) sync_2dff [63:0] (
    .clk_i      (clk_dst),
    .d_i        (din    ),
    .rstn_i     (rstn   ),
    .q_o        (dout   )
  );

  // initial begin $dumpfile("waves.vcd"); $dumpvars; end

  initial begin
    repeat(3) @(posedge clk_dst);
    rstn = '1;
    #2;
    din[2] = '1;
    #1;
    din[2] = '0;
    #1;
    din[2] = '1;
    #1;
    din[2] = '0;
    #1;
    repeat (100000000) @(posedge clk_dst);
    $finish();
  end

endmodule
