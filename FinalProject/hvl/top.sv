`define SRC 0
`define RAND 1
`define TESTBENCH `SRC
// `define TESTBENCH `RAND

import rv32i_types::*;

module mp4_tb;
`timescale 1ns/10ps

/********************* Do not touch for proper compilation *******************/
// Instantiate Interfaces
tb_itf itf();
rvfi_itf rvfi(itf.clk, itf.rst);

// Instantiate Testbench
generate
if (`TESTBENCH == `SRC) begin : source
    source_tb tb(
        .magic_mem_itf(itf),
        .mem_itf(itf),
        .sm_itf(itf),
        .tb_itf(itf),
        .rvfi(rvfi)
    );
end
else begin : random
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


/************************ Signals necessary for monitor **********************/
// This section not required until CP2

// Set high when a valid instruction is modifying regfile or PC
assign rvfi.commit = dut.i_cpu.i_rob.flag_commit_i;

// Set high when target PC == Current PC for a branch
assign rvfi.halt = rvfi.commit & (dut.i_cpu.i_rob.pc_i == dut.i_cpu.i_rob.pc_i_n); 

// Instruction buffers
logic [$clog2(SIZE_ROB)-1:0] p_start, p_end;
logic [SIZE_ROB-1:0][31:0] buf_inst;
logic [SIZE_ROB-1:0][4:0] buf_rs1_addr, buf_rs2_addr;
logic [SIZE_ROB-1:0] buf_trap;

// Memory buffers
logic buf_ren;
logic buf_wen;
logic [31:0] buf_addr;
logic [3:0] buf_mask;
logic [31:0] buf_rdata;
logic [31:0] buf_wdata;

initial begin
    p_start <= {$clog2(SIZE_ROB){1'b0}};
    p_end <= {$clog2(SIZE_ROB){1'b0}};
    buf_ren <= 1'b0;
    buf_wen <= 1'b0;
end

// Buffer data at issue stage
always @(posedge itf.clk) begin
    if (dut.i_cpu.i_rob.flag_flush_i)
        p_end <= dut.i_cpu.i_rob.br_id + 1;
    else
        if (dut.i_cpu.issue_req) begin
            p_end <= p_end + 1;
            buf_trap[p_end] <= dut.i_cpu.i_issuer.trap;
            buf_inst[p_end] <= dut.i_cpu.iq_inst;
            buf_rs1_addr[p_end] <= dut.i_cpu.issue_sr1;
            buf_rs2_addr[p_end] <= dut.i_cpu.issue_sr2;
        end
end

// Buffer data at memory access stage
always @(posedge itf.clk iff dut.i_cpu.i_lsq.data_mem_resp) begin
    buf_ren <= dut.i_cpu.i_lsq.data_read;
    buf_wen <= dut.i_cpu.i_lsq.data_write;
    buf_addr <= dut.i_cpu.i_lsq.data_mem_address;
    buf_mask <= dut.i_cpu.i_lsq.data_mbe;
    buf_rdata <= dut.i_cpu.i_lsq.data_mem_rdata;
    buf_wdata <= dut.i_cpu.i_lsq.data_mem_wdata;
    @(posedge itf.clk iff rvfi.commit);
    buf_ren <= 1'b0;
    buf_wen <= 1'b0;
end

// Pop out data after instruction commits
initial rvfi.order = 0;
always @(posedge itf.clk iff rvfi.commit) begin
    p_start <= p_start + 1;
    rvfi.order <= rvfi.order + 1;
    if (rvfi.order % 2000 == 0)
        $display("sample commit #%6d: %8h", rvfi.order, rvfi.inst);
end

// Assign signals
always_comb begin
    // rvfi.commit
    // rvfi.order
    rvfi.inst = buf_inst[p_start];
    rvfi.trap = buf_trap[p_start];
    // rvfi.halt
    // 1'b0
    // 2'b00
    rvfi.rs1_addr = buf_rs1_addr[p_start];
    rvfi.rs2_addr = buf_rs2_addr[p_start];
    rvfi.rs1_rdata = dut.i_cpu.i_regfile.data[buf_rs1_addr[p_start]];
    rvfi.rs2_rdata = dut.i_cpu.i_regfile.data[buf_rs2_addr[p_start]];
    rvfi.load_regfile = dut.i_cpu.commit_rf_en;
    rvfi.rd_addr = dut.i_cpu.commit_rd;
    rvfi.rd_wdata = dut.i_cpu.commit_rd ? dut.i_cpu.commit_data : 0;
    rvfi.pc_rdata = dut.i_cpu.i_rob.pc_i;
    rvfi.pc_wdata = dut.i_cpu.i_rob.pc_i_n;
    rvfi.mem_addr = (buf_wen || buf_ren) ? buf_addr : 32'b0;
    rvfi.mem_rmask = buf_ren ? buf_mask : 4'b0;
    rvfi.mem_wmask = buf_wen ? buf_mask : 4'b0;
    rvfi.mem_rdata = buf_ren ? buf_rdata : 32'b0;
    rvfi.mem_wdata = buf_wen ? buf_wdata : 32'b0;
    // 1'b0
    // rvfi.errcode
end

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
