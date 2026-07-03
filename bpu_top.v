module bpu #(
    parameter PC_BITS = 6,
    parameter LOCAL_HIST_BITS = 10,  
    parameter GLOBAL_HIST_BITS = 12,
    parameter INSTR_SIZE = 4
)(
    input clk, reset, update_en, update_branch_taken,
    input [31:0] fetch_pc, update_pc, update_target,
    input [LOCAL_HIST_BITS-1:0] update_local_hist,
    input [GLOBAL_HIST_BITS-1:0] update_global_hist,
    output [31:0] next_pc,
    output predict_taken, btb_hit_out,
    output [LOCAL_HIST_BITS-1:0] fetch_local_hist,
    output [GLOBAL_HIST_BITS-1:0] fetch_global_hist
    );

    wire predictor_taken, btb_hit;
    wire [31:0] btb_target, not_taken_target;

    assign not_taken_target=fetch_pc+INSTR_SIZE;

    TournamentPredictor #(
        .PC_BITS(PC_BITS),
        .LOCAL_HIST_BITS(LOCAL_HIST_BITS),
        .GLOBAL_HIST_BITS(GLOBAL_HIST_BITS)
    ) predictor_inst (
        .clk(clk),
        .reset(reset),
        .fetch_pc(fetch_pc),
        .final_prediction(predictor_taken),
        .fetch_local_hist(fetch_local_hist),
        .fetch_global_hist(fetch_global_hist),
        .update_en(update_en),
        .update_pc(update_pc),
        .update_local_hist(update_local_hist),
        .update_global_hist(update_global_hist),
        .branch_taken(update_branch_taken)
    );

    BTB #(
        .PC_BITS(PC_BITS)
    ) btb_inst (
        .clk(clk),
        .reset(reset),
        .fetch_pc(fetch_pc),
        .btb_hit(btb_hit),
        .btb_target(btb_target),
        .update_en(update_en),
        .update_pc(update_pc),
        .update_target(update_target),
        .branch_taken(update_branch_taken)
    );

    assign predict_taken=predictor_taken&btb_hit;
    assign btb_hit_out=btb_hit;
    assign next_pc=(predict_taken)?btb_target:not_taken_target;

endmodule
