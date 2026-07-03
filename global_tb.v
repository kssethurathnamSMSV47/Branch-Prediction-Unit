`timescale 1ns / 1ps

module tb_GlobalPred;

    // --- Parameters ---
    parameter PHT_INDEX_BITS = 6;
    parameter GHR_BITS       = 4;

    // --- Signals ---
    reg clk;
    reg reset;
    
    // Fetch Stage
    reg [31:0] fetch_pc;
    wire prediction;
    wire [GHR_BITS-1:0] predict_history_out;
    
    // Execute Stage
    reg update_en;
    reg [31:0] update_pc;
    reg [GHR_BITS-1:0] update_history_in;
    reg branch_taken;

    // --- Metrics Tracking ---
    integer total_branches = 0;
    integer correct_preds  = 0;

    // --- Instantiate the Unit Under Test (UUT) ---
    GlobalPred #(
        .PHT_INDEX_BITS(PHT_INDEX_BITS),
        .GHR_BITS(GHR_BITS)
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

    // --- Evaluation Task ---
    task evaluate_branch(input [31:0] pc, input actual_outcome);
        reg [GHR_BITS-1:0] captured_history;
        reg is_correct;
        begin
            // FETCH STAGE
            fetch_pc = pc;
            #1;
            captured_history = predict_history_out;
            is_correct = (prediction == actual_outcome);
            
            total_branches = total_branches + 1;
            if (is_correct) correct_preds = correct_preds + 1;

            $display("PC: %08h | GHR: %b | Pred: %b | Actual: %b | %s", 
                     pc, captured_history, prediction, actual_outcome, 
                     is_correct ? "CORRECT" : "MISPREDICT");

            // Pipeline delay
            @(posedge clk); 
            #1;

            // EXECUTE STAGE
            update_en = 1;
            update_pc = pc;
            update_history_in = captured_history;
            branch_taken = actual_outcome;

            @(posedge clk);
            #1;
            update_en = 0;
        end
    endtask

    // --- Main Test Sequence ---
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
        // TEST 1: LONG LOOP
        // ---------------------------------------------------------
        $display("\n--- TEST 1: LONG LOOP (PC = 0x00000020) ---");
        for (i = 0; i < 10; i = i + 1)
            evaluate_branch(32'h0000_0020, 1'b1);
        evaluate_branch(32'h0000_0020, 1'b0);

        // ---------------------------------------------------------
        // TEST 2: ALTERNATING PATTERN
        // ---------------------------------------------------------
        $display("\n--- TEST 2: ALTERNATING PATTERN (PC = 0x30) ---");
        for (i = 0; i < 12; i = i + 1)
            evaluate_branch(32'h0000_0030, (i % 2 == 0));

        // ---------------------------------------------------------
        // TEST 3: INTERLEAVED BRANCHES
        // ---------------------------------------------------------
        $display("\n--- TEST 3: INTERLEAVED CORRELATION ---");
        for (i = 0; i < 5; i = i + 1) begin
            evaluate_branch(32'h0000_0040, 1'b1);
            evaluate_branch(32'h0000_0050, 1'b0);
        end

        // ---------------------------------------------------------
        // TEST 4: CORRELATED BRANCHES
        // ---------------------------------------------------------
        $display("\n--- TEST 4: CORRELATED PATTERN ---");
        for (i = 0; i < 8; i = i + 1) begin
            evaluate_branch(32'h0000_0060, (i % 2));
            evaluate_branch(32'h0000_0070, (i % 2));
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
