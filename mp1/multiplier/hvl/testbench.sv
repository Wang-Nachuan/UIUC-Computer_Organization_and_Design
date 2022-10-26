
`ifndef testbench
`define testbench
module testbench(multiplier_itf.testbench itf);
import mult_types::*;

add_shift_multiplier dut (
    .clk_i          ( itf.clk          ),
    .reset_n_i      ( itf.reset_n      ),
    .multiplicand_i ( itf.multiplicand ),
    .multiplier_i   ( itf.multiplier   ),
    .start_i        ( itf.start        ),
    .ready_o        ( itf.rdy          ),
    .product_o      ( itf.product      ),
    .done_o         ( itf.done         )
);

assign itf.mult_op = dut.ms.op;
default clocking tb_clk @(negedge itf.clk); endclocking

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars();
end

// DO NOT MODIFY CODE ABOVE THIS LINE

/* Uncomment to "monitor" changes to adder operational state over time */
//initial $monitor("dut-op: time: %0t op: %s", $time, dut.ms.op.name);


// Resets the multiplier
task reset();
    itf.reset_n <= 1'b0;
    ##5;
    itf.reset_n <= 1'b1;
    ##1;
endtask : reset

// error_e defined in package mult_types in file ../include/types.sv
// Asynchronously reports error in DUT to grading harness
function void report_error(error_e error);
    itf.tb_report_dut_error(error);
endfunction : report_error


/********************** Self-define Blocks/Parameters *****************************/

reg [15:0] cur_mult_vector;
wire [15:0] expect_result;

assign expect_result = cur_mult_vector[15:8] * cur_mult_vector[7:0];
assign itf.multiplicand = cur_mult_vector[7:0];
assign itf.multiplier = cur_mult_vector[15:8];

// Sequencer: multiplication
task seq_mult();
    for (int i = 0; i <= 16'hffff; i++) begin
        @(tb_clk iff itf.rdy);
        itf.start <= 1'b1;
        ##1;
        itf.start <= 1'b0;
        @(tb_clk iff itf.done);        
        ##1;
        itf.reset_n <= 1'b0;
        ##1;
        itf.reset_n <= 1'b1;
        cur_mult_vector <= cur_mult_vector + 16'b1;
    end
endtask

// Sequencer: assert start_i for each run state
task seq_start();
    ##1;
    itf.reset_n <= 1'b0;
    cur_mult_vector <= 16'habcd;
    ##1;
    itf.reset_n <= 1'b1;
    @(tb_clk iff itf.rdy);
    itf.start <= 1'b1;
    ##1;
    itf.start <= 1'b0;

    @(tb_clk iff dut.ms.op == ADD)
    itf.start <= 1'b1;
    ##1;
    itf.start <= 1'b0;

    @(tb_clk iff dut.ms.op == SHIFT)
    itf.start <= 1'b1;
    ##1;
    itf.start <= 1'b0;
endtask

// Sequencer: assert active-low reset_n_i for each run state
task seq_reset();
    ##1;
    itf.reset_n <= 1'b0;
    cur_mult_vector <= 16'habcd;
    ##1;
    itf.reset_n <= 1'b1;
    @(tb_clk iff itf.rdy);
    itf.start <= 1'b1;
    ##1;
    itf.start <= 1'b0;

    @(tb_clk iff dut.ms.op == ADD)
    itf.reset_n <= 1'b0;
    ##1;
    itf.reset_n <= 1'b1;

    @(tb_clk iff dut.ms.op == SHIFT)
    itf.reset_n <= 1'b0;
    ##1;
    itf.reset_n <= 1'b1;
endtask

// Monitor: multiplication
always @ (tb_clk iff itf.done) begin
    assert (itf.product == expect_result)
    else begin
        $error ("%0d: %0t: BAD_PRODUCT error detected", `__LINE__, $time);
        report_error (BAD_PRODUCT);
    end
    assert (itf.rdy == 1'b1)
    else begin
        $error ("%0d: %0t: NOT_READY error detected", `__LINE__, $time);
        report_error (NOT_READY);
    end
end

// Monitor: reset
always @ (tb_clk iff itf.reset_n == 1'b0) begin
    @ (tb_clk iff itf.reset_n == 1'b1)
    assert (itf.rdy == 1'b1)
    else begin
        $error ("%0d: %0t: NOT_READY error detected", `__LINE__, $time);
        report_error (NOT_READY);
    end
end


initial itf.reset_n = 1'b0;
initial begin
    reset();
    /********************** Your Code Here *****************************/
    cur_mult_vector <= 16'b0;
    
    seq_mult();
    seq_start();
    seq_reset();
    
    /*******************************************************************/
    itf.finish(); // Use this finish task in order to let grading harness
                  // complete in process and/or scheduled operations
    $error("Improper Simulation Exit");
end

endmodule : testbench
`endif
