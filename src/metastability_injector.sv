/**
* Module: metastability_injector.sv
*
* Description:
*   Injects metastability into 2dff synchronizers on data changes, by sampling data and determining when
*   it is possible for a metastable event to occur in hardware. Simulates the discrepency in timing between
*   the hardware-world and the simulation-world of the output of data from a 2dff synchronizer.
*
*   Models setup violations in which the data settles to new value as non-metastable events
*   Models hold violations in which the data settles to old value as non-metastable events
*/
`default_nettype none
module metastability_injector (
  input   wire  clk_i,                                  // I : synchronizing clock
  input   wire  rstn_i,                                 // I : active low reset
  input   wire  d_i,                                    // I : the data input for the synchronizer
  input   wire  sync_ff1_i,                             // I : the value of the first synchronizing flip-flop
  input   wire  sync_ff2_i,                             // I : the value of the second synchronizing flip-flop
  output  logic setup_violation_o,                      // O : violation resulting in a three-cycle synchronization latency
  output  logic hold_violation_o,                       // O : violation resulting in a one-cycle synchronization latency
  output  logic filter_detect_o,                        // O : prevent filtering due to metastability insertion
  output  logic d_previous_o                            // O : flopped d_i value
);

  //****************************************************************************
  //* metastability generation logic signals
  //****************************************************************************
  wire [6:0]  rng_transition_timing;                    // random number representing the timing of the transition
  wire        rng_violation_type;                       // random bit representing the type of violation which occured (setup/hold)
  logic       meta_sampled;                             // metastability occured causing a variation in synchronization latency

  assign meta_sampled = setup_violation_o | hold_violation_o;

  //****************************************************************************
  //* hierarchical enabling/disabling of metastability
  //****************************************************************************
  bit     enable_metastability  = '1;                   // dial to enable/disable metastability from the plusargs - enabled by default
  string  hierarchy             = $sformatf("%m");      // the hierarchy of the current synchronizer module
  bit     instance_selected     = '0;                   // if the current instance is in the plusarg_hierarchies
  string  plusarg_hierarchies;                          // a comma seperated string of hierarchies passed to the plusargs
  int     l_ptr = 0, r_ptr = 0, h_ptr = 0, p_ptr = 0;   // pointers for parsing the hierarchies

  initial begin : parse_hierarchies

    if($value$plusargs("metastability_hierarchy_toggle=%s", plusarg_hierarchies)) begin
      for (r_ptr = 0; r_ptr < plusarg_hierarchies.len(); r_ptr++) begin

        // if current character is not a comma or the last, continue parsing
        if(plusarg_hierarchies[r_ptr] != "," && r_ptr != plusarg_hierarchies.len() - 1) continue;

        h_ptr = 0;
        p_ptr = l_ptr;

        // while hierarchy pointer is in bounds && the end of the plusarg hierarchy isnt reached
        while(h_ptr != hierarchy.len() - 1 && p_ptr <= r_ptr) begin
          if(plusarg_hierarchies[p_ptr] == hierarchy[h_ptr]) begin
            h_ptr++;
            p_ptr++;
          end else begin
            if(plusarg_hierarchies[p_ptr] != "*") break;
            if(h_ptr == hierarchy.len())          break;
            for(; h_ptr != hierarchy.len() && hierarchy[h_ptr] != "."; h_ptr++);
            if(p_ptr == r_ptr)                    break;
            p_ptr++;
          end
        end

        // if there is a match between instance hierarchy and plusarg hierarchy
        if(p_ptr == r_ptr &&
            (plusarg_hierarchies[p_ptr] == hierarchy[h_ptr] || plusarg_hierarchies[p_ptr] == "*") &&
            (h_ptr == hierarchy.len() - 1 || hierarchy[h_ptr] == "."))
        begin
          instance_selected = '1;
          break;
        end

        l_ptr = r_ptr + 1;
      end
    end

    // logic to enable/disable metastability based on local and global switches
    $value$plusargs("global_metastability_enable=%d", enable_metastability);
    enable_metastability = enable_metastability ? ~instance_selected : instance_selected;

  end : parse_hierarchies

  //****************************************************************************
  //* plusarg abstractly representing the size of the setup and hold window
  //****************************************************************************
  int meta_window;
  initial begin
    if($value$plusargs("metastability_probability=%d", meta_window))
      meta_window = ((meta_window * 128) / 100);
    else
      meta_window = 64;                                 // default to 50% chance of metastability
  end

  //****************************************************************************
  //* (Pseudo-)Random Number Generator from a Linear-Feedback Shift Register
  //****************************************************************************
  lfsr_8bit i_lfsr(
    .clk_i              (clk_i                                      ),
    .d_o                ({rng_transition_timing, rng_violation_type})
  );

  always_ff @(d_i, posedge clk_i, negedge rstn_i) begin

    setup_violation_o   <= '0;
    hold_violation_o    <= '0;
    filter_detect_o     <= '0;

    //****************************************************************************
    //* Metastable events are generated when all conditions hold true:
    //* - the design is not being reset
    //* - a transition in data occurs
    //* - the last sample was stable
    //* - the last sample is not at risk of filtering
    //* - the timing of the transition was within the setup or hold window
    //****************************************************************************
    if(
      (rstn_i)                                      &&
      (d_i != d_previous_o)                         &&
      (!meta_sampled)                               &&
      (!filter_detect_o)                            &&
      (int'(rng_transition_timing) <= meta_window)
    ) begin

      // randomly select between a setup violation or a hold violation
      if(rng_violation_type && (sync_ff1_i == sync_ff2_i)) 
        hold_violation_o  <= enable_metastability;
      else
        setup_violation_o <= enable_metastability;

    end

    //****************************************************************************
    //* If:
    //* - the design is not being reset and
    //* - a transition in data occurs and
    //* - the last sample was metastable or at risk of filtering
    //* Then signal to use stored value instead of d_i to prevent data filtering
    //****************************************************************************
    else if(
      (rstn_i)                          &&
      (d_i != d_previous_o)             &&
      (meta_sampled | filter_detect_o)
    ) begin
      filter_detect_o <= '1;
    end
  end

  always_ff @(posedge clk_i) begin
    d_previous_o  <= d_i;
  end

endmodule
`default_nettype wire
