
module testbench(cam_itf itf);
import cam_types::*;

cam dut (
    .clk_i     ( itf.clk     ),
    .reset_n_i ( itf.reset_n ),
    .rw_n_i    ( itf.rw_n    ),
    .valid_i   ( itf.valid_i ),
    .key_i     ( itf.key     ),
    .val_i     ( itf.val_i   ),
    .val_o     ( itf.val_o   ),
    .valid_o   ( itf.valid_o )
);

default clocking tb_clk @(negedge itf.clk); endclocking

initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars();
end

task reset();
    itf.reset_n <= 1'b0;
    repeat (5) @(tb_clk);
    itf.reset_n <= 1'b1;
    repeat (5) @(tb_clk);
endtask

// DO NOT MODIFY CODE ABOVE THIS LINE

task write(input key_t key, input val_t val);
    ##1;
    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    itf.key <= key;
    itf.val_i <= val;
    ##1;
    itf.valid_i <= 1'b0;
endtask

task read(input key_t key, output val_t val);
    ##1;
    itf.rw_n <= 1'b1;
    itf.valid_i <= 1'b1;
    itf.key <= key;
    @(tb_clk iff itf.valid_o );
    val <= itf.val_o;
    ##1;
    itf.valid_i <= 1'b0;
endtask

/********************** Self-define Blocks/Parameters *****************************/

reg [15:0] out;
reg [15:0] cur_key;

task test();

    for (int i = 0; i < 8; i++) begin
        write(i, i);
    end

    ##5;

    for (int i = 0; i < 8; i++) begin
        read(i, out);
    end

    ##5;

    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    itf.key <= 8;
    itf.val_i <= 9;
    ##1;
    itf.key <= 8;
    itf.val_i <= 8;
    ##1;
    itf.valid_i <= 1'b0;

    ##5;

    itf.rw_n <= 1'b0;
    itf.valid_i <= 1'b1;
    itf.key <= 8;
    itf.val_i <= 8;
    ##1;
    itf.rw_n <= 1'b1;
    @(tb_clk iff itf.valid_o );
    out <= itf.val_o;
    ##1;
    itf.valid_i <= 1'b0;

    ##5;

    for (int i = 9; i < 17; i++) begin
        write(i, i);
    end

endtask

// Monitor
always @(tb_clk iff itf.valid_o ) begin
    assert (itf.key == itf.val_o)
    else begin
        itf.tb_report_dut_error(READ_ERROR);
        $error("%0t TB: Read %0d, expected %0d", $time, itf.val_o, itf.key);
    end
end

initial begin
    $display("Starting CAM Tests");

    reset();
    /************************** Your Code Here ****************************/
    // Feel free to make helper tasks / functions, initial / always blocks, etc.
    // Consider using the task skeltons above
    // To report errors, call itf.tb_report_dut_error in cam/include/cam_itf.sv

    test();

    /**********************************************************************/

    itf.finish();
end

endmodule : testbench
