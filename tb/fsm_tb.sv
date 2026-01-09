/*
  Example FSM Module
  This module implements a simple finite state machine (FSM) that reacts to an asynchronous pulse input.
  The FSM has four states: IDLE, WAIT, PROCESS, and DONE. It increments a 4-bit counter each time it cycles through the states.
  The asynchronous pulse input is synchronized to the clock domain using a 2-flip-flop synchronizer.

  The catch is that one of the states requires the pulse to be stable for two clock cycles before transitioning to the next state.
*/
module example_fsm #(
  parameter DYNAMIC_CDC = 1   // Enable dynamic CDC model if set to 1
)(
  input logic clk_i,          // Clock input
  input logic rst_ni,         // Active low reset
  input logic async_pulse_i,  // Asynchronous pulse input which the FSM reacts to
  output logic [15:0] count_o  // 4-bit output counter, increments on each FSM cycling
);

  logic sync_pulse_i; // synchronized version of async_pulse_i
  logic pulse_bb;     // double-buffered version of sync_pulse_i

  sync_2dff #(
    .SYNTHESIS(DYNAMIC_CDC)
  ) u_sync_2dff (
    .clk_i  (clk_i),
    .d_i    (async_pulse_i),
    .rstn_i (rst_ni),
    .q_o    (sync_pulse_i)
  );

  always_ff @(posedge clk_i) begin
    pulse_bb <= sync_pulse_i;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      count_o <= '0;
    end else if (current_state == DONE) begin
      count_o <= count_o + 16'h1;
    end
  end

  typedef enum logic [2:0] {
    IDLE,
    WAIT,
    PROCESS,
    DONE
  } fsm_state_t;

  fsm_state_t current_state, next_state;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (sync_pulse_i) next_state = WAIT;
      end
      WAIT: begin
        next_state = PROCESS;
      end
      PROCESS: begin // requires the pulse to be stable for two cycles
        if(sync_pulse_i && pulse_bb) next_state = DONE;
        else next_state = PROCESS;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule


module fsm_tb;

  localparam halfperiod_src = 8ns;
  localparam halfperiod_dst = 5ns;
  localparam random_inputs  = 1;

  bit clk_src;
  bit clk_dst;
  bit rst;
  bit din;
  logic [15:0] count_out_no_dcdc;
  logic [15:0] count_out_dcdc;

  always #halfperiod_src  clk_src = ~clk_src;
  always #halfperiod_dst  clk_dst = ~clk_dst;

  initial begin $dumpfile("waves.vcd"); $dumpvars; end

  always @(posedge clk_src) begin
    din = 1'($urandom_range(0,1));
  end

  //****************************************************************************
  //* DUTs
  //****************************************************************************
  initial begin
    rst = '0;
    repeat(2) @(posedge clk_dst);
    rst = '1;
    repeat(10000) @(posedge clk_dst);
    force din = 1'b0;
    repeat(10) @(posedge clk_dst);
    $finish;
  end

  example_fsm #(
    .DYNAMIC_CDC    (0                )
  ) u_example_fsm_no_dcdc (
    .clk_i          (clk_dst          ),
    .rst_ni         (rst              ),
    .async_pulse_i  (din              ),
    .count_o        (count_out_no_dcdc)
  );

  example_fsm #(
    .DYNAMIC_CDC    (1                )
  ) u_example_fsm_dcdc (
    .clk_i          (clk_dst         ),
    .rst_ni         (rst             ),
    .async_pulse_i  (din             ),
    .count_o        (count_out_dcdc  )
  );

endmodule
