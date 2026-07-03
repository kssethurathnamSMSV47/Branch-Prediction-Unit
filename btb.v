module BTB #(
    parameter PC_BITS = 6   
)(
    input clk,
    input reset,

    // Fetch stage 
    input  [31:0] fetch_pc,
    output reg btb_hit,
    output reg [31:0] btb_target,

    // Execute stage 
    input update_en,
    input  [31:0] update_pc,
    input  [31:0] update_target,
    input  branch_taken   
);

    // storage
    reg [31:0] tag_array     [0:(1 << PC_BITS)-1];
    reg [31:0] target_array  [0:(1 << PC_BITS)-1];
    reg valid [0:(1 << PC_BITS)-1];

    integer i;

    // indexing
    wire [PC_BITS-1:0] fetch_idx  = fetch_pc[PC_BITS+1:2];
    wire [PC_BITS-1:0] update_idx = update_pc[PC_BITS+1:2];

    // fetch
    always @(*) begin
        if (valid[fetch_idx] && tag_array[fetch_idx] == fetch_pc) begin
            btb_hit    = 1'b1;
            btb_target = target_array[fetch_idx];
        end else begin
            btb_hit    = 1'b0;
            btb_target = 32'b0;
        end
    end

    // update
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < (1 << PC_BITS); i = i + 1) begin
                valid[i] <= 1'b0;
                tag_array[i] <= 32'b0;
                target_array[i] <= 32'b0;
            end
        end 
        else if (update_en && branch_taken) begin
            // store only when branch is taken 
            valid[update_idx] <= 1'b1;
            tag_array[update_idx] <= update_pc;
            target_array[update_idx] <= update_target;
        end
    end

endmodule
