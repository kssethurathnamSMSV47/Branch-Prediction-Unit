module ChoicePred #( // 4096x2 choice predictor
    parameter GHR_BITS = 12 
)(
    input clk, reset,
  
    // fetch stuff
    input [GHR_BITS-1:0] fetch_ghr, // 12-bit GHR
    output reg use_global_pred, // mux control

    // execute stuff
    input update_en, // HIGH when branch resolves
    input [GHR_BITS-1:0] update_ghr, // ghr when branch fetched
    input local_prediction, // local pred
    input global_prediction, // global pred
    input branch_taken // final pred
);

    parameter STRONGLY_LOCAL = 2'b00, WEAKLY_LOCAL = 2'b01, WEAKLY_GLOBAL = 2'b10, STRONGLY_GLOBAL = 2'b11;

    // Choice Pattern Table (CPT): 2^GHR_BITS entries of 2-bit counters
    reg [1:0] cpt[0:(1<<GHR_BITS)-1];
    integer i;

    wire local_correct = (local_prediction==branch_taken);
    wire global_correct = (global_prediction==branch_taken);

    // fetch stuff
    always @(*) begin
        case (cpt[fetch_ghr])
            STRONGLY_LOCAL, WEAKLY_LOCAL: use_global_pred = 1'b0; // select local
            WEAKLY_GLOBAL, STRONGLY_GLOBAL: use_global_pred = 1'b1; // select global
            default: use_global_pred = 1'b0;
        endcase
    end

    // execute stuff
    always @(posedge clk) 
    begin
        if (reset) 
        begin
            for (i=0; i<(1<<GHR_BITS); i=i+1) 
            cpt[i] <= WEAKLY_GLOBAL; // resetting to weakly global
        end 
        else if (update_en) 
        begin
            case ({local_correct,global_correct})
                2'b10: 
                begin 
                    if (cpt[update_ghr]!=STRONGLY_LOCAL)
                    cpt[update_ghr] <= cpt[update_ghr]-1'b1;
                end
                2'b01: 
                begin 
                    if (cpt[update_ghr]!=STRONGLY_GLOBAL)
                    cpt[update_ghr] <= cpt[update_ghr]+1'b1;
                end
                default: cpt[update_ghr] <= cpt[update_ghr];
            endcase
        end
    end

endmodule
