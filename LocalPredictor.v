module TwoLevelLocalPred #(parameter PC_BITS=6, parameter HIST_BITS=4) 
(
    input clk, reset,
    // fetch stage stuff
    input [31:0] fetch_pc,       
    output reg prediction,
    output [HIST_BITS-1:0] predict_history_out,
    
    // execute stage stuff
    input update_en,               // HIGH when branch resolves
    input [31:0] update_pc,        // PC of the resolving branch
    input [HIST_BITS-1:0] update_history_in, // the history used during fetch
    input branch_taken             // actual outcome
);

parameter STRONGLY_NOT_TAKEN=2'b00, WEAKLY_NOT_TAKEN=2'b01, WEAKLY_TAKEN=2'b10, STRONGLY_TAKEN=2'b11; // states for 2 bit counter

reg [HIST_BITS-1:0] lht[0:(1<<PC_BITS)-1]; // LHT :- Local history table , indexed by PC, gives the history pattern for that PC
reg [1:0] pht[0:(1<<HIST_BITS)-1]; // PHT :- Pattern history table, indexed by the history pattern, gives the 2 bit counter for that pattern

wire [PC_BITS-1:0] fetch_idx=fetch_pc[PC_BITS+1:2]; // useful fetch

integer i;
wire [PC_BITS-1:0] update_idx = update_pc[PC_BITS+1:2];

assign predict_history_out=lht[fetch_idx]; // history

always @(*)               // to find if branch predicted to be taken or not
begin
        case (pht[predict_history_out])
            STRONGLY_NOT_TAKEN, WEAKLY_NOT_TAKEN: prediction = 1'b0; 
            WEAKLY_TAKEN, STRONGLY_TAKEN: prediction = 1'b1; 
            default: prediction = 1'b0;
        endcase
end

always @(posedge clk) 
begin
        if (reset) 
        begin
            for (i=0; i<(1<<PC_BITS); i=i+1) 
            lht[i] <= 0; // initializing to 0
            for (i=0; i<(1<<HIST_BITS); i=i+1) 
            pht[i] <= WEAKLY_TAKEN; // initializing counters
        end
        else if (update_en) 
        begin
            // update the PHT counter using the prev(old) history passed from the pipeline
            case ({pht[update_history_in], branch_taken})
                {STRONGLY_NOT_TAKEN, 1'b0}: pht[update_history_in] <= STRONGLY_NOT_TAKEN;
                {STRONGLY_NOT_TAKEN, 1'b1}: pht[update_history_in] <= WEAKLY_NOT_TAKEN;
                
                {WEAKLY_NOT_TAKEN, 1'b0}: pht[update_history_in] <= STRONGLY_NOT_TAKEN;
                {WEAKLY_NOT_TAKEN, 1'b1}: pht[update_history_in] <= WEAKLY_TAKEN;
                
                {WEAKLY_TAKEN, 1'b0}: pht[update_history_in] <= WEAKLY_NOT_TAKEN;
                {WEAKLY_TAKEN, 1'b1}: pht[update_history_in] <= STRONGLY_TAKEN;
                
                {STRONGLY_TAKEN, 1'b0}: pht[update_history_in] <= WEAKLY_TAKEN;
                {STRONGLY_TAKEN, 1'b1}: pht[update_history_in] <= STRONGLY_TAKEN;
            endcase

            // update the LHT for this specific PC by shifting in the actual outcome
            lht[update_idx] <= {update_history_in[HIST_BITS-2:0], branch_taken};
        end
end

endmodule
