`ifndef testbench
`define testbench


module testbench(fifo_itf itf);
import fifo_types::*;

fifo_synch_1r1w dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),

    // valid-ready enqueue protocol
    .data_i    ( itf.data_i  ),
    .valid_i   ( itf.valid_i ),
    .ready_o   ( itf.rdy     ),

    // valid-yumi deqeueue protocol
    .valid_o   ( itf.valid_o ),
    .data_o    ( itf.data_o  ),
    .yumi_i    ( itf.yumi    )
);

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars();
end

// Clock Synchronizer for Student Use
default clocking tb_clk @(negedge itf.clk); endclocking

task reset();
    itf.reset_n <= 1'b0;
    ##(10);
    itf.reset_n <= 1'b1;
    ##(1);
endtask : reset

function automatic void report_error(error_e err); 
    itf.tb_report_dut_error(err);
endfunction : report_error

// DO NOT MODIFY CODE ABOVE THIS LINE

/********************** Self-define Blocks/Parameters *****************************/

reg [7:0] expect_result;

task fill_fifo(input int num);
    @(tb_clk iff itf.rdy);
    for (int i = 0; i < num; i++) begin
        ##1;
        itf.data_i <= i;
        itf.valid_i <= 1'b1;
    end
    ##1;
    itf.valid_i <= 1'b0;
endtask

task enq();
    ##1; 
    itf.reset_n <= 1'b0;
    ##1; 
    itf.reset_n <= 1'b1;
    fill_fifo(cap_p-1);
endtask

task deq();
    ##1; 
    itf.reset_n <= 1'b0;
    ##1; 
    itf.reset_n <= 1'b1;
    expect_result <= 8'b0;
    fill_fifo(cap_p);
    ##1;
    itf.yumi <= 1'b1;
    for (int i = 0; i < cap_p; i++) begin
        assert (itf.data_o == expect_result)
        else begin
            $error ("%0d: %0t: INCORRECT_DATA_O_ON_YUMI_I error detected", `__LINE__, $time);
            report_error (INCORRECT_DATA_O_ON_YUMI_I);
        end
        expect_result <= expect_result + 8'b1;
        ##1;
    end
    itf.yumi <= 1'b0;
endtask

task enq_deq();
    for (int cnt = 1; cnt <= cap_p-1; cnt++) begin
        ##1; 
        itf.reset_n <= 1'b0;
        ##1; 
        itf.reset_n <= 1'b1;
        
        fill_fifo(cnt);
        ##1;
        itf.data_i <= 1;
        itf.valid_i <= 1'b1;
        itf.yumi <= 1'b1;
        expect_result <= cnt;
        ##1;
        itf.valid_i <= 1'b0;
        itf.yumi <= 1'b0;
    end
endtask

// Monitors
always @(tb_clk iff itf.reset_n == 0) begin
    @(posedge itf.clk);
    assert (itf.rdy == 1'b1)
    else begin
        $error ("%0d: %0t: RESET_DOES_NOT_CAUSE_READY_O error detected", `__LINE__, $time);
        report_error (RESET_DOES_NOT_CAUSE_READY_O);
    end
end

initial begin
    reset();
    /************************ Your Code Here ***********************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.
    enq();
    deq();
    enq_deq();
    
    /***************************************************************/
    // Make sure your test bench exits by calling itf.finish();
    itf.finish();
    $error("TB: Illegal Exit ocurred");
end

endmodule : testbench
`endif

