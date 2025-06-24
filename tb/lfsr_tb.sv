/**
* Module: lfsr_tb.sv
*
* Description:
*   Testbench for the lfsr_8bit module. Verifies the functionality of the 8-bit Linear Feedback Shift Register
*   by simulating its operation and checking for sequence repetition.
*/
`default_nettype none

module lfsr_tb;

  bit         clk;            // Clock signal for the LFSR
  logic [7:0] lfsr8;          // Output of the 8-bit LFSR
  longint     cycles;         // Counter for simulation cycles
  int         initial_value;  // Stores the initial seed value of the LFSR

  // Instantiate the 8-bit LFSR module
  lfsr_8bit u_lfsr8 (
    .clk_i (clk   ),
    .d_o   (lfsr8 )
  );  
  
  // Clock generation
  always #5  clk = ~clk;

  // Capture the initial seed value and simulate until the LFSR sequence repeats it
  initial begin
    @(posedge clk);
    initial_value = u_lfsr8.seed;
    do @(posedge clk) cycles++; while (initial_value != u_lfsr8.d);
    $display("LFSR repeated after %0d cycles...", cycles);
    $finish();
  end

endmodule
`default_nettype wire
