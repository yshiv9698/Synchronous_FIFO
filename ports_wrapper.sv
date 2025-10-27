
// complex_module.sv
// Large example module for simulation, linting, or waveform testing
// Demonstrates wide ports, internal logic, and multiple always blocks

module complex_module (
    input  clk,
    input  rst_n,

    // Control signals
    input  [4:0] mode_sel,
    input  [7:0] opcode,
    output  [1:0] cfg_bits,

    // Data inputs
    input  [7:0]  data_in_a,
    input  [15:0] data_in_b,
    input  [31:0] data_in_c,
    input  [64:0] data_in_d,

    // Outputs
    output [7:0]  result_a,
    output [18:0] result_b,
    output [31:0] status_word,
    output [63:0] combined_out
);

    // -------------------------------
    // Internal logic declarations
    // -------------------------------
    logic [7:0]  alu_result;
    logic [15:0] sum_reg, diff_reg;
    logic [31:0] mult_reg;
    logic [63:0] conca_reg;
    logic [3:0]  mode_reg;
    logic [7:0]  counter;
    logic ready_flag, enable_op, valid_op;
    logic [1:0]  op_state;
    logic [15:0] internal_mem [0:15];
    logic [31:0] data_pipe [0:7];

    // -------------------------------
    // State machine for operation control
    // -------------------------------
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        LOAD  = 2'b01,
        EXEC  = 2'b10,
        DONE  = 2'b11
    } state_t;

    state_t current_state, next_state;

    // Sequential state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE:  if (enable_op) next_state = LOAD;
            LOAD:  next_state = EXEC;
            EXEC:  next_state = DONE;
            DONE:  if (!enable_op) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------
    // Control logic
    // -------------------------------
    always_comb begin
        enable_op = (opcode != 8'h00);
        valid_op  = (mode_sel != 4'hF);
    end

    // -------------------------------
    // Data processing logic
    // -------------------------------
    always_comb begin
        case (opcode)
            8'h01: alu_result = data_in_a + data_in_b[7:0];
            8'h02: alu_result = data_in_a - data_in_b[7:0];
            8'h03: alu_result = data_in_a ^ data_in_b[7:0];
            8'h04: alu_result = data_in_a & data_in_b[7:0];
            8'h05: alu_result = data_in_a | data_in_b[7:0];
            8'h06: alu_result = data_in_a << 1;
            8'h07: alu_result = data_in_a >> 1;
            default: alu_result = 8'hAA;
        endcase
    end

    // -------------------------------
    // Sequential registers
    // -------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 0;
            sum_reg   <= 0;
            diff_reg  <= 0;
            mult_reg  <= 0;
            concat_reg <= 0;
            mode_reg  <= 0;
            ready_flag <= 0;
        end else begin
            counter <= counter + 1;
            sum_reg <= data_in_a + data_in_b[7:0];
            diff_reg <= data_in_b - data_in_a;
            mult_reg <= data_in_c * counter;
            concat_reg <= {data_in_d[31:0], data_in_c[31:0]};
            mode_reg <= mode_sel;
            ready_flag <= (current_state == DONE);
        end
    end

    // -------------------------------
    // Example: simple memory behavior
    // -------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n)
            for (int i = 0; i < 16; i++) internal_mem[i] <= 16'd0;
        else if (enable_op)
            internal_mem[counter[3:0]] <= data_in_b + counter;
    end

    // -------------------------------
    // Example: data pipeline
    // -------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) data_pipe[i] <= 32'd0;
        end else begin
            data_pipe[0] <= data_in_c;
            for (int j = 1; j < 8; j++)
                data_pipe[j] <= data_pipe[j-1];
        end
    end

    // -------------------------------
    // Output assignments
    // -------------------------------
    assign result_a    = alu_result;
    assign result_b    = sum_reg + diff_reg;
    assign status_word = {mode_reg, ready_flag, 3'b000, opcode, counter};
    assign combined_out = concat_reg ^ {data_in_d[31:0], data_in_c[31:0]};

endmodule
