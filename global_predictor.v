module GlobalPred #(
    parameter PHT_INDEX_BITS = 6,  // pattern history table 
    parameter GHR_BITS = 4  //global history register
)(
    input clk, 
    input reset,

    // Fetch Stage stuff
    input  [31:0] fetch_pc,               
    output reg prediction,     //output of global prediction unit            
    output [GHR_BITS-1:0] predict_history_out, 

    // Execute Stage stuff
    input  update_en,                     
    input  [31:0] update_pc,              
    input  [GHR_BITS-1:0] update_history_in, 
    input  branch_taken                   
);

// Logic
parameter STRONGLY_NOT_TAKEN=2'b00, WEAKLY_NOT_TAKEN=2'b01, WEAKLY_TAKEN=2'b10, STRONGLY_TAKEN=2'b11; // states for 2 bit counter
integer i;

reg [GHR_BITS-1:0] ghr;
reg [1:0] pht[0:(1<<PHT_INDEX_BITS)-1];

// fetch stage
wire [PHT_INDEX_BITS-1:0] fetch_pc_idx=fetch_pc[PHT_INDEX_BITS+1:2]; 
wire [PHT_INDEX_BITS-1:0] xored_idx= fetch_pc_idx^{{(PHT_INDEX_BITS-GHR_BITS){1'b0}},ghr}; // xor logic 

//update stage 
wire [PHT_INDEX_BITS-1:0] update_pc_idx=update_pc[PHT_INDEX_BITS+1:2]; 
wire [PHT_INDEX_BITS-1:0] update_xored_idx= update_pc_idx^{{(PHT_INDEX_BITS-GHR_BITS){1'b0}},update_history_in}; //xor logic 

// output current history 
assign predict_history_out=ghr;

always@(*) 
    begin
        case(pht[xored_idx]) 
            STRONGLY_NOT_TAKEN,WEAKLY_NOT_TAKEN: prediction=1'b0;
            STRONGLY_TAKEN,WEAKLY_TAKEN: prediction=1'b1;
            default: prediction=1'b0;
        endcase
    end

always@(posedge clk)
    begin
        if(reset)
            begin 
                ghr<=0;
                for(i=0;i<(1<<PHT_INDEX_BITS);i=i+1)
                    pht[i]<=WEAKLY_TAKEN; 
            end 
        else if(update_en)
            begin
                case({pht[update_xored_idx],branch_taken})
                    {STRONGLY_NOT_TAKEN,1'b0}: pht[update_xored_idx]<=STRONGLY_NOT_TAKEN;
                    {STRONGLY_NOT_TAKEN,1'b1}: pht[update_xored_idx]<=WEAKLY_NOT_TAKEN;

                    {WEAKLY_NOT_TAKEN,1'b0}: pht[update_xored_idx]<=STRONGLY_NOT_TAKEN;
                    {WEAKLY_NOT_TAKEN,1'b1}: pht[update_xored_idx]<=WEAKLY_TAKEN;
                    
                    {WEAKLY_TAKEN,1'b0}: pht[update_xored_idx]<=WEAKLY_NOT_TAKEN;
                    {WEAKLY_TAKEN,1'b1}: pht[update_xored_idx]<=STRONGLY_TAKEN;
                    
                    {STRONGLY_TAKEN,1'b0}: pht[update_xored_idx]<=WEAKLY_TAKEN;
                    {STRONGLY_TAKEN,1'b1}: pht[update_xored_idx]<=STRONGLY_TAKEN;
                endcase
            // update ghr
            ghr<={update_history_in[GHR_BITS-2:0],branch_taken};
            end
    end


endmodule
