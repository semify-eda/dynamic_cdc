/**
* Module: sync_2dff.sv
*
* Description:
*   Implements a 2-stage D flip-flop (2DFF) synchronizer for clock domain crossing (CDC).
*   This module is designed to mitigate metastability issues when transferring data
*   between asynchronous clock domains. It includes a parameter for synthesis and
*   integrates with a metastability injector for dynamic simulation of metastability.
*/
`default_nettype none
module sync_2dff #(
  parameter SYNTHESIS               = 0,  // Parameter to make design synthesizable (disables all modeling)
  parameter ENABLE_GLITCH_MONITOR   = 0   // Parameter to enable/disable the glitch monitor
)(
  input  wire                       clk_i,  // I : Clock input for the destination domain
  input  wire                       d_i,    // I : Asynchronous Data input from the source domain
  input  wire                       rstn_i, // I : Asynchronous active low reset input
  output logic                      q_o     // O : Synchronized Data output in the destination domain
);


  //****************************************************************************
  //* Synchronizer Flip-Flops
  //****************************************************************************
  logic sync_ff1;
  logic sync_ff2;

  assign q_o = sync_ff2;

  //****************************************************************************
  //* Synthesizable Synchronizer
  //****************************************************************************
  generate if(SYNTHESIS) begin : synthesis

    always_ff @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
        sync_ff1  <= '0;
        sync_ff2  <= '0;
      end else begin
        sync_ff1  <= d_i;
        sync_ff2  <= sync_ff1;
      end
    end

  end : synthesis


  //****************************************************************************
  //* Dynamic CDC model
  //****************************************************************************
  else begin : metastability_model

    logic setup_violation;
    logic hold_violation;
    logic filter_detect;
    logic d_prev;

    metastability_injector i_metastability_injector (
      .clk_i              (clk_i          ),
      .rstn_i             (rstn_i         ),
      .d_i                (d_i            ),
      .sync_ff1_i         (sync_ff1       ),
      .sync_ff2_i         (sync_ff2       ),
      .setup_violation_o  (setup_violation),
      .hold_violation_o   (hold_violation ),
      .filter_detect_o    (filter_detect  ),
      .d_previous_o       (d_prev         )
    );

    always_ff @(posedge clk_i or negedge rstn_i) begin
      if (~rstn_i) begin
        sync_ff1  <= '0;
        sync_ff2  <= '0;
      end else begin
        sync_ff1  <= filter_detect   ? d_prev : setup_violation ? sync_ff1   : d_i;
        sync_ff2  <= hold_violation  ? d_i    : sync_ff1;
      end
    end

    if(ENABLE_GLITCH_MONITOR) begin : glitch_monitor
      event glitch;
      glitch_monitor i_glitch_monitor(
        .clk_i    (clk_i  ),
        .d_i      (d_i    ),
        .rstn_i   (rstn_i ),
        .glitch_o (glitch )
      );
    end : glitch_monitor

  end : metastability_model endgenerate


endmodule
`default_nettype wire
