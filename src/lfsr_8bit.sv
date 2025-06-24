/**
* Module: lfsr_8bit.sv
*
* Description:
*   Implements a non-synthesizable 32-bit Linear Feedback Shift Register (LFSR)
*   using an Xorshift algorithm. Generates a pseudo-random sequence of bits where
*   the bottom 8 bits are used as output. Has a cycle time of (2^32 - 1) before
*   8-bit sequences start repeating.
*/
`default_nettype none
module lfsr_8bit (
  input  wire         clk_i,  // I : Clock input for the LFSR
  output logic [7:0]  d_o     // O : 8-bit pseudo-random output from the LFSR
);

  // Shift amounts for the 32-bit Xorshift. Marsaglia's triple (13, 17, 5) is chosen
  // to provide a maximal cycle length (2^32 - 1 states) for a 32-bit register.
  localparam int SHIFT_A = 13;
  localparam int SHIFT_B = 17;
  localparam int SHIFT_C = 5;

  int unsigned    seed;                           // Internal seed for the LFSR
  int unsigned    d;                              // Current pseudo-random value
  int unsigned    plusarg_seed;                   // Seed value from plusarg
  string          seed_string  = $sformatf("%m"); // Instance name

  initial begin : hierarchical_seeding
    // Initialize seed based on hierarchy string
    foreach(seed_string[i]) begin
      seed += int'(seed_string[i]);
    end
    // Check for plusargs to further randomize the seed
    if($value$plusargs("metastability_seed=%d", plusarg_seed)) begin
      seed ^= int'(plusarg_seed);
    end else if($test$plusargs("random_metastability_seed")) begin
      // Implementation of $urandom is vendor specific...
      // i.e can be affected by running with or without coverage, assertions, etc.
      seed ^= int'($urandom());
    end
    // if the seed happens to be 0, seed it to non-zero value
    d = (seed == '0) ? int'(32'hdeadbeef) : seed;
  end : hierarchical_seeding

  always @(posedge clk_i) begin
    d = d ^ (d << SHIFT_A);
    d = d ^ (d >> SHIFT_B);
    d = d ^ (d << SHIFT_C);
  end

  // Assign the lower 8 bits of the pseudo-random value to the output
  assign d_o = d[7:0];

endmodule
`default_nettype wire
