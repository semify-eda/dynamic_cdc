/**
* Module: glitch_monitor.sv
*
* Description:
*   Monitors a data signal for glitches (i.e., transient changes that return to the original value
*   within a single clock cycle). Clock period is configured dynamically when reset is asserted.
*   This module is particularly useful in detecting potential filtering of input data during CDC,
*   when input data is not held high for an entire destination clock cycle (+ setup & hold) 
*/
`default_nettype none
module glitch_monitor(
  input   wire  clk_i,    // I : Clock input for monitoring
  input   wire  d_i,      // I : Data signal to be monitored for glitches
  input   wire  rstn_i,   // I : Active low reset input
  output  event glitch_o  // O : Glitch on data input
);

  realtime  clk_period;             // Calculated Clock Period. Dynamically calculated on resets.
  realtime  last_clk;               // Stores the time of the last positive clock edge
  realtime  last_d_transition;      // Stores the time of the last data transition
  bit       clk_period_configured;  // Flag to indicate if clock period has been configured
  bit       last_clk_configured;    // Flag to indicate if last_clk has been configured

  // Logic to calculate the clock period based on clock edges and reset
  always @(posedge clk_i, posedge rstn_i) begin
    if(~rstn_i) begin
      last_clk            <= $realtime;
      last_clk_configured <= '1;
      if(last_clk_configured) begin
        clk_period            <= $realtime - last_clk;
        clk_period_configured <= '1;
      end
    end else begin
      last_clk_configured <= '0;
    end
  end

  // A glitch is detected if the time between data transitions is less than a clock period
  // and the clock period has been configured.
  always @(d_i) begin
    last_d_transition <= $realtime;
    as_glitch_monitor: assert (($realtime - last_d_transition >= clk_period) || !clk_period_configured)
    else begin
      ->> glitch_o;
      // TODO: Having a display statement destroys simulation time, keep as a failing assertion or replace with a UVM message
      // $display("[ERROR@%0t] [Instance] %m\nGlitch occured on data input. Ensure data is constant for more than 1 cycle", $realtime);
    end
  end

endmodule
`default_nettype wire
