`define SRC 0
`define RAND 1
// `define TESTBENCH `SRC
`define TESTBENCH `RAND

import rv32i_types::*;

module mp4_tb;
`timescale 1ns/10ps

/********************* Do not touch for proper compilation *******************/
// Instantiate Interfaces
tb_itf itf();
rvfi_itf rvfi(itf.clk, itf.rst);

// Instantiate Testbench
generate
if (`TESTBENCH == `SRC) begin
    source_tb tb(
        .magic_mem_itf(itf),
        .mem_itf(itf),
        .sm_itf(itf),
        .tb_itf(itf),
        .rvfi(rvfi)
    );
end
else begin
    random_tb tb(
        .itf(itf), 
        .mem_itf(itf)
    );
end
endgenerate

// Dump signals
initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars(0, mp4_tb, "+all");
end
/****************************** End do not touch *****************************/

// Stop simulation on timeout (stall detection), halt
// int timeout = 1000000;   // Feel Free to adjust the timeout value
// always @(posedge itf.clk) begin
//     if (rvfi.halt)
//         $finish;
//     if (timeout == 0) begin
//         $display("TOP: Timed out");
//         $finish;
//     end
//     timeout <= timeout - 1;
// end

/************************ Signals necessary for monitor **********************/
// This section not required until CP2

// Set high when a valid instruction is modifying regfile or PC
assign rvfi.commit = dut.i_cpu.i_rob.flag_commit_i;

// Set high when target PC == Current PC for a branch
assign rvfi.halt = rvfi.commit & (dut.i_cpu.i_rob.pc_i == dut.i_cpu.i_rob.pc_i_n); 

/*
    Instruction and trap:
        rvfi.inst
        rvfi.trap

    Regfile:
        rvfi.rs1_addr
        rvfi.rs2_addr
        rvfi.rs1_rdata
        rvfi.rs2_rdata
        rvfi.load_regfile
        rvfi.rd_addr
        rvfi.rd_wdata

    PC:
        rvfi.pc_rdata
        rvfi.pc_wdata

    Memory:
        rvfi.mem_addr
        rvfi.mem_rmask
        rvfi.mem_wmask
        rvfi.mem_rdata
        rvfi.mem_wdata

    Please refer to rvfi_itf.sv for more information.
*/
logic [$clog2(SIZE_ROB)-1:0] p_start, p_end;
logic [SIZE_ROB-1:0][31:0] buf_inst;
logic [SIZE_ROB-1:0][4:0] buf_rs1_addr, buf_rs2_addr;

initial begin
    p_start <= {$clog2(SIZE_ROB){1'b0}};
    p_end <= {$clog2(SIZE_ROB){1'b0}};
end

// Buffer data until instruction commits
always @(posedge itf.clk iff dut.i_cpu.issue_req) begin
    p_end <= p_end + 1;
    buf_inst[p_end] <= dut.i_cpu.iq_inst;
    buf_rs1_addr[p_end] <= dut.i_cpu.issue_sr1;
    buf_rs2_addr[p_end] <= dut.i_cpu.issue_sr2;
end

// Pop out data after instruction commits
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) begin
    p_start <= p_start + 1;
    rvfi.order <= rvfi.order + 1; // Modify for OoO (?)
end

riscv_formal_monitor_rv32imc monitor(
    .clock(itf.clk),
    .reset(itf.rst),
    .rvfi_valid(rvfi.commit),
    .rvfi_order(rvfi.order),
    .rvfi_insn(buf_inst[p_start]),
    .rvfi_trap(dut.i_cpu.i_issuer.trap),
    .rvfi_halt(rvfi.halt),
    .rvfi_intr(1'b0),
    .rvfi_mode(2'b00),
    .rvfi_rs1_addr(buf_rs1_addr[p_start]),
    .rvfi_rs2_addr(buf_rs2_addr[p_start]),
    .rvfi_rs1_rdata(dut.i_cpu.i_regfile.data[buf_rs1_addr[p_start]]),
    .rvfi_rs2_rdata(dut.i_cpu.i_regfile.data[buf_rs2_addr[p_start]]),
    .rvfi_rd_addr(dut.i_cpu.commit_rf_en ? dut.i_cpu.commit_rd : 5'b0),
    .rvfi_rd_wdata(monitor.rvfi_rd_addr ? dut.i_cpu.commit_data : 32'b0),
    .rvfi_pc_rdata(dut.i_cpu.i_rob.pc_i),
    .rvfi_pc_wdata(dut.i_cpu.i_rob.pc_i_n),
    .rvfi_mem_addr(32'b0),
    .rvfi_mem_rmask(4'b0),
    .rvfi_mem_wmask(4'b0),
    .rvfi_mem_rdata(32'b0),
    .rvfi_mem_wdata(32'b0),
    .rvfi_mem_extamo(1'b0),
    .errcode(rvfi.errcode)
);

/**************************** End RVFIMON signals ****************************/

/********************* Assign Shadow Memory Signals Here *********************/
// This section not required until CP2
/*
The following signals need to be set:
icache signals:
    itf.inst_read
    itf.inst_addr
    itf.inst_resp
    itf.inst_rdata

dcache signals:
    itf.data_read
    itf.data_write
    itf.data_mbe
    itf.data_addr
    itf.data_wdata
    itf.data_resp
    itf.data_rdata

Please refer to tb_itf.sv for more information.
*/

/*********************** End Shadow Memory Assignments ***********************/

// Set this to the proper value
assign itf.registers = '{default: '0};

/*********************** Instantiate your design here ************************/
/*
The following signals need to be connected to your top level for CP2:
Burst Memory Ports:
    itf.mem_read
    itf.mem_write
    itf.mem_wdata
    itf.mem_rdata
    itf.mem_addr
    itf.mem_resp

Please refer to tb_itf.sv for more information.
*/

mp4 dut(
    .clk(itf.clk),
    .rst(itf.rst),
    
    // Remove after CP1
    .instr_mem_resp(itf.inst_resp),
    .instr_mem_rdata(itf.inst_rdata),
	.data_mem_resp(itf.data_resp),
    .data_mem_rdata(itf.data_rdata),
    .instr_read(itf.inst_read),
	.instr_mem_address(itf.inst_addr),
    .data_read(itf.data_read),
    .data_write(itf.data_write),
    .data_mbe(itf.data_mbe),
    .data_mem_address(itf.data_addr),
    .data_mem_wdata(itf.data_wdata)


    /* Use for CP2 onwards
    .pmem_read(itf.mem_read),
    .pmem_write(itf.mem_write),
    .pmem_wdata(itf.mem_wdata),
    .pmem_rdata(itf.mem_rdata),
    .pmem_address(itf.mem_addr),
    .pmem_resp(itf.mem_resp)
    */
);
/***************************** End Instantiation *****************************/

endmodule : mp4_tb
