`timescale 1ns / 1ps

module tb_TwoLevelLocal_HighAcc;

    parameter PC_BITS   = 6;
    parameter HIST_BITS = 4;

    reg clk;
    reg reset;

    reg  [31:0] fetch_pc;
    wire        prediction;
    wire [HIST_BITS-1:0] predict_history_out;

    reg  update_en;
    reg  [31:0] update_pc;
    reg  [HIST_BITS-1:0] update_history_in;
    reg  branch_taken;

    integer total_branches = 0;
    integer correct_preds  = 0;

    TwoLevelLocalPred #(
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

    always #5 clk = ~clk;

    task evaluate_branch(input [31:0] pc, input actual_outcome);
        reg [HIST_BITS-1:0] captured_history;
        reg is_correct;
        begin
            fetch_pc = pc;
            #1;
            captured_history = predict_history_out;
            is_correct = (prediction == actual_outcome);

            total_branches = total_branches + 1;
            if (is_correct) correct_preds = correct_preds + 1;

            $display("PC: %08h | Hist: %b | Pred: %b | Actual: %b | %s",
                     pc, captured_history, prediction, actual_outcome,
                     is_correct ? "CORRECT" : "MISPREDICT");

            @(posedge clk);
            #1;

            update_en         = 1;
            update_pc         = pc;
            update_history_in = captured_history;
            branch_taken      = actual_outcome;

            @(posedge clk);
            #1;
            update_en = 0;
        end
    endtask

    integer i;

    // A period-4 pattern -- fits exactly in HIST_BITS=4, so once the local
    // history register cycles through its 4 states, prediction is perfect.
    reg pattern4 [0:3];

    initial begin
        clk = 0;
        reset = 1;
        fetch_pc = 0;
        update_en = 0;
        update_pc = 0;
        update_history_in = 0;
        branch_taken = 0;

        pattern4[0] = 1'b1;
        pattern4[1] = 1'b1;
        pattern4[2] = 1'b0;
        pattern4[3] = 1'b0;

        #15 reset = 0;

        // ---------------------------------------------------------
        // TEST 1: Long always-taken loop at a single PC.
        // Only the very first prediction (cold, history=0) can miss;
        // everything after saturates and stays correct.
        // ---------------------------------------------------------
        $display("\n--- TEST 1: LONG ALWAYS-TAKEN LOOP (PC = 0x20), 40 iters ---");
        for (i = 0; i < 40; i = i + 1)
            evaluate_branch(32'h0000_0020, 1'b1);

        // ---------------------------------------------------------
        // TEST 2: Long always-not-taken loop at a different PC.
        // ---------------------------------------------------------
        $display("\n--- TEST 2: LONG ALWAYS-NOT-TAKEN LOOP (PC = 0x40), 40 iters ---");
        for (i = 0; i < 40; i = i + 1)
            evaluate_branch(32'h0000_0040, 1'b0);

        // ---------------------------------------------------------
        // TEST 3: Period-4 repeating pattern at its own PC.
        // History width == pattern period, so after ~1 lap the
        // predictor locks on and every subsequent prediction is correct.
        // ---------------------------------------------------------
        $display("\n--- TEST 3: PERIOD-4 PATTERN (PC = 0x60), 60 iters ---");
        for (i = 0; i < 60; i = i + 1)
            evaluate_branch(32'h0000_0060, pattern4[i % 4]);

        // ---------------------------------------------------------
        // TEST 4: A second, independent period-4 branch, to also check
        // that local history tables don't cross-pollute each other.
        // ---------------------------------------------------------
        $display("\n--- TEST 4: PERIOD-4 PATTERN, DIFFERENT PC (PC = 0x70), 60 iters ---");
        for (i = 0; i < 60; i = i + 1)
            evaluate_branch(32'h0000_0070, pattern4[(i + 2) % 4]);

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
