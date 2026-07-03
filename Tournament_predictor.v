module TournamentPredictor #(
    parameter PC_BITS = 6,
    parameter LOCAL_HIST_BITS = 10,  
    parameter GLOBAL_HIST_BITS = 12  
)(
    input clk, reset,

    // fetch stuff
    input  [31:0] fetch_pc,
    output final_prediction,
    
    // use these in pipeline
    output [LOCAL_HIST_BITS-1:0] fetch_local_hist,
    output [GLOBAL_HIST_BITS-1:0] fetch_global_hist,

    // execute staff
    input update_en,
    input [31:0] update_pc,
    input [LOCAL_HIST_BITS-1:0] update_local_hist,
    input [GLOBAL_HIST_BITS-1:0] update_global_hist,
    input branch_taken
);

    wire local_pred_out, global_pred_out, use_global_pred;

    TwoLevelLocalPred #(.PC_BITS(PC_BITS),.HIST_BITS(LOCAL_HIST_BITS)) local_pred(.clk(clk),.reset(reset),.fetch_pc(fetch_pc),.predict_history_out(fetch_local_hist),.prediction(local_pred_out),.update_en(update_en),.update_pc(update_pc),.update_history_in(update_local_hist),.branch_taken(branch_taken));
    GlobalPred #(.PHT_INDEX_BITS(GLOBAL_HIST_BITS), .GHR_BITS(GLOBAL_HIST_BITS)) global_pred(.clk(clk),.reset(reset),.fetch_pc(fetch_pc),.prediction(global_pred_out),.predict_history_out(fetch_global_hist),.update_en(update_en),.update_pc(update_pc),.update_history_in(update_global_hist),.branch_taken(branch_taken));
    ChoicePred #(.GHR_BITS(GLOBAL_HIST_BITS)) choice_pred(.clk(clk),.reset(reset),.fetch_ghr(fetch_global_hist),.use_global_pred(use_global_pred),.update_en(update_en),.update_ghr(update_global_hist),.local_prediction(local_pred_out),.global_prediction(global_pred_out),.branch_taken(branch_taken));

    assign final_prediction = use_global_pred?global_pred_out:local_pred_out; // final mux

endmodule
