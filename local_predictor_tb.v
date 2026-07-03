// sample tb to check predictor

`timescale 1ns / 1ps

module tb_TwoLevelLocal_Complex;

    // --- Parameters ---
    parameter PC_BITS = 6;
    parameter HIST_BITS = 4;

    // --- Signals ---
    reg clk;
    reg reset;
    
    // Fetch Stage
    reg [31:0] fetch_pc;
    wire prediction;
    wire [HIST_BITS-1:0] predict_history_out;
    
    // Execute Stage
    reg update_en;
    reg [31:0] update_pc;
    reg [HIST_BITS-1:0] update_history_in;
    reg branch_taken;

    // --- Metrics Tracking ---
    integer total_branches = 0;
    integer correct_preds = 0;

    // --- Instantiate the Unit Under Test (UUT) ---
    TwoLevelLocalPredictor #(
        .PC_BITS(PC_BITS),
        .HIST_BITS(HIST_BITS)
    ) uut (
        .clk(clk),
        .reset(reset),
        .fetch_pc(fetch_pc),
        .prediction(prediction),
        .predict_history_out(predict_history_out),
        .update_en(update_en),
        .update_pc(update_pc),
        .update_history_in(update_history_in),
        .branch_taken(branch_taken)
    );

    // --- Clock Generation ---
    always #5 clk = ~clk; 

    // --- Upgraded Task with Accuracy Tracking ---
    task evaluate_branch(input [31:0] pc, input actual_outcome);
        reg [HIST_BITS-1:0] captured_history;
        reg is_correct;
        begin
            // 1. FETCH STAGE
            fetch_pc = pc;
            #1; // Combinational delay
            captured_history = predict_history_out;
            is_correct = (prediction == actual_outcome);
            
            // Track metrics
            total_branches = total_branches + 1;
            if (is_correct) correct_preds = correct_preds + 1;

            $display("PC: %08h | Hist: %b | Pred: %b | Actual: %b | %s", 
                     pc, captured_history, prediction, actual_outcome, 
                     is_correct ? "CORRECT" : "MISPREDICT");

            // Pipeline delay
            @(posedge clk); 
            #1; 

            // 2. EXECUTE STAGE
            update_en = 1;
            update_pc = pc;
            update_history_in = captured_history; 
            branch_taken = actual_outcome;
            
            @(posedge clk); 
            #1; 
            update_en = 0;
        end
    endtask

    // --- Main Complex Test Sequence ---
    integer i;
    
    initial begin
        clk = 0;
        reset = 1;
        fetch_pc = 0;
        update_en = 0;
        update_pc = 0;
        update_history_in = 0;
        branch_taken = 0;

        #15 reset = 0;
        
        // ---------------------------------------------------------
        // TEST 1: The Long Loop (Saturation Test)
        // A loop that runs 10 times, then exits.
        // ---------------------------------------------------------
        $display("\n--- TEST 1: LONG LOOP (PC = 0x00000020) ---");
        for (i = 0; i < 10; i = i + 1) begin
            evaluate_branch(32'h0000_0020, 1'b1); // Taken 10 times
        end
        evaluate_branch(32'h0000_0020, 1'b0);     // Loop Exits (Not-Taken)


        // ---------------------------------------------------------
        // TEST 2: The Alternating Pattern (T, N, T, N...)
        // A basic predictor fails this 100%. A local predictor 
        // with 4-bit history will learn it perfectly after 4 cycles!
        // ---------------------------------------------------------
        $display("\n--- TEST 2: ALTERNATING PATTERN (PC = 0x00000030) ---");
        for (i = 0; i < 12; i = i + 1) begin
            evaluate_branch(32'h0000_0030, (i % 2 == 0) ? 1'b1 : 1'b0);
        end


        // ---------------------------------------------------------
        // TEST 3: Interleaved Branches (Independence Test)
        // Two branches back-to-back. PC 0x40 is always Taken. 
        // PC 0x50 is always Not-Taken. They should not corrupt each other.
        // ---------------------------------------------------------
        $display("\n--- TEST 3: INTERLEAVED INDEPENDENCE ---");
        for (i = 0; i < 5; i = i + 1) begin
            evaluate_branch(32'h0000_0040, 1'b1); // Always T
            evaluate_branch(32'h0000_0050, 1'b0); // Always N
        end

        // --- Final Report ---
        #20;
        $display("\n========================================");
        $display("          SIMULATION COMPLETE           ");
        $display("========================================");
        $display("Total Branches : %0d", total_branches);
        $display("Correct Preds  : %0d", correct_preds);
        $display("Accuracy       : %0d %%", (correct_preds * 100) / total_branches);
        $display("========================================\n");
        $finish;
    end

endmodule
