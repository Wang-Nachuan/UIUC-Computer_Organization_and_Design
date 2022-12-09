module mp4
import rv32i_types::*;
(
    input clk,
    input rst,
    input pmem_resp,
    input [63:0] pmem_rdata,
    output logic pmem_read,
    output logic pmem_write,
    output rv32i_word pmem_address,
    output [63:0] pmem_wdata
);

    logic       icache_resp;
    logic [63:0]  icache_rdata;
    logic       icache_read;
    rv32i_word  icache_address;
    logic       dcache_resp;
    rv32i_word  dcache_rdata;
    logic       dcache_read;
    logic       dcache_write;
    logic [3:0] dcache_byte_enable;
    rv32i_word  dcache_address;
    rv32i_word  dcache_wdata;

    /* the out-of-order cpu */
    cpu i_cpu(
        .clk(clk),
        .rst(rst),
        /* port from instruction cache */
        .inst_mem_resp(icache_resp),
        .inst_mem_rdata(icache_rdata),
        /* port to instruction cache */
        .inst_read(icache_read),
        .inst_mem_address(icache_address),
        /* port from data cache */
        .data_mem_resp(dcache_resp),
        .data_mem_rdata(dcache_rdata),
        /* port to data cache */
        .data_read(dcache_read),
        .data_write(dcache_write),
        .data_mbe(dcache_byte_enable),
        .data_mem_address(dcache_address),
        .data_mem_wdata(dcache_wdata)
    );

    logic           icache_pmem_resp;
    logic           icache_pmem_read;
    logic [255:0]   icache_pmem_rdata;
    rv32i_word      icache_pmem_address;
    logic           dcache_pmem_resp;
    logic           dcache_pmem_read;
    logic           dcache_pmem_write;
    logic [255:0]   dcache_pmem_wdata;
    logic [255:0]   dcache_pmem_rdata;
    rv32i_word      dcache_pmem_address;

    /* instruction cache */
    i_cache icache(
        .clk,
        .rst,
        .mem_read(icache_read),
        .mem_address(icache_address),
        .mem_resp(icache_resp),
        .mem_rdata(icache_rdata),
        .icache_pmem_resp(icache_pmem_resp),
        .icache_pmem_rdata(icache_pmem_rdata),
        .icache_pmem_address(icache_pmem_address),
        .icache_pmem_read(icache_pmem_read)
    );

    logic hold_arbiter;

    d_cache dcache(
        .clk,
        .rst,
        //input from cpu
        .mem_address(dcache_address),
        .mem_wdata(dcache_wdata),
        .mem_read(dcache_read),
        .mem_write(dcache_write),
        .mem_byte_enable(dcache_byte_enable),
        //output to cpu
        .mem_rdata(dcache_rdata),
        .mem_resp(dcache_resp),
        //output to physical memory or L2 cache
        .dcache_pmem_rdata(dcache_pmem_rdata),
        .dcache_pmem_resp(dcache_pmem_resp),
        //input from physical memory or L2 cache
	    .hold_arbiter(hold_arbiter),
        .dcache_pmem_wdata(dcache_pmem_wdata),
        .dcache_pmem_address(dcache_pmem_address),
        .dcache_pmem_read(dcache_pmem_read),
        .dcache_pmem_write(dcache_pmem_write)
    );

    logic           arbiter_resp;
    logic           arbiter_read;
    logic           arbiter_write;
    logic [255:0]   arbiter_wdata;
    logic [255:0]   arbiter_rdata;
    rv32i_word      arbiter_address;

    arbiter arbiter_inst(
        .clk,
        .rst,
        //icache input and output
        .icache_pmem_address(icache_pmem_address),
        .icache_pmem_read(icache_pmem_read),
        .icache_pmem_resp(icache_pmem_resp),
        .icache_pmem_rdata  (icache_pmem_rdata),
        //dcache output or input
        .dcache_pmem_address(dcache_pmem_address),
        .dcache_pmem_read(dcache_pmem_read),
        .dcache_pmem_write(dcache_pmem_write),
        .dcache_pmem_wdata(dcache_pmem_wdata),
	    .hold_arbiter(hold_arbiter),
        .dcache_pmem_resp(dcache_pmem_resp),
        .dcache_pmem_rdata(dcache_pmem_rdata),
        //to physical memory
        .pmem_resp_arbiter(arbiter_resp),
        .pmem_rdata_arbiter(arbiter_rdata),
        .pmem_address_arbiter(arbiter_address),
        .pmem_read_arbiter(arbiter_read),
        .pmem_write_arbiter(arbiter_write),
        .pmem_wdata_arbiter(arbiter_wdata)
    );

    generate 
	if (use_l2==1) begin

	logic 				l2_mem_read;
	logic 				l2_mem_write;
	logic 				l2_mem_resp;
	logic 		[31:0]	l2_mem_address;
	logic 		[255:0]	l2_mem_rdata_256;
	logic 		[255:0]	l2_mem_wdata_256;
    l2_d_cache l2_dcache(
        .clk(clk),
        .rst(rst),
        //input
        .mem_address(arbiter_address),
        .mem_wdata(arbiter_wdata),
        .mem_read(arbiter_read),
        .mem_write(arbiter_write),
        //.mem_byte_enable(),
        //output
        .mem_rdata(arbiter_rdata),
        .mem_resp(arbiter_resp),
        //output to physical memory or L2 cache
        .dcache_pmem_rdata(l2_mem_rdata_256),
        .dcache_pmem_resp(l2_mem_resp),
        //input from physical memory or L2 cache
	    .hold_arbiter(),
        .dcache_pmem_wdata(l2_mem_wdata_256),
        .dcache_pmem_address(l2_mem_address),
        .dcache_pmem_read(l2_mem_read),
        .dcache_pmem_write(l2_mem_write)
    );

    cacheline_adaptor cacheline_adaptor_inst(
        .clk,
        .reset_n(~rst),
        //from/to cache
        //l1
        // .line_i(arbiter_wdata),
        // .line_o(arbiter_rdata),
        // .address_i(arbiter_address),
        // .read_i(arbiter_read),
        // .write_i(arbiter_write),
        // .resp_o(arbiter_resp),
        .line_i(l2_mem_wdata_256),
        .line_o(l2_mem_rdata_256),
        .address_i(l2_mem_address),
        .read_i(l2_mem_read),
        .write_i(l2_mem_write),
        .resp_o(l2_mem_resp),
        //from/to physcial memory
        .burst_i(pmem_rdata),
        .burst_o(pmem_wdata),
        .address_o(pmem_address),
        .read_o(pmem_read),
        .write_o(pmem_write),
        .resp_i(pmem_resp)
    );
	end else begin
	cacheline_adaptor cacheline_adaptor_inst(
        .clk,
        .reset_n(~rst),
        //from/to cache
        .line_i(arbiter_wdata),
        .line_o(arbiter_rdata),
        .address_i(arbiter_address),
        .read_i(arbiter_read),
        .write_i(arbiter_write),
        .resp_o(arbiter_resp),
        //from/to physcial memory
        .burst_i(pmem_rdata),
        .burst_o(pmem_wdata),
        .address_o(pmem_address),
        .read_o(pmem_read),
        .write_o(pmem_write),
        .resp_i(pmem_resp)
    );

	end

endgenerate

endmodule : mp4
