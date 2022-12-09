module arbiter
(
	input 	logic					clk,
	input 	logic					rst,
	// from icache
	input 	logic 				icache_pmem_read,
	input 	logic 		[31:0]	icache_pmem_address,
	output 	logic 				icache_pmem_resp,
	output 	logic 		[255:0]	icache_pmem_rdata,
	// from dcache
	input 	logic 				dcache_pmem_read,
	input 	logic 				dcache_pmem_write,
	input 	logic 		[31:0]	dcache_pmem_address,
	input 	logic 		[255:0]	dcache_pmem_wdata,
	input   logic               hold_arbiter,
	output 	logic 				dcache_pmem_resp,
	output 	logic 		[255:0]	dcache_pmem_rdata,
	// to cacheline adaptor or l2-cache
	output 	logic 		[255:0]	pmem_wdata_arbiter,
	input 	logic 		[255:0]	pmem_rdata_arbiter,
	output 	logic 		[31:0]	pmem_address_arbiter,
	output 	logic 				pmem_read_arbiter,
	output 	logic 				pmem_write_arbiter,
	input 	logic 				pmem_resp_arbiter
);

	enum logic [1:0]{
		icache_state,
		dcache_state,
		idle
	} state, next_state;

	always_comb begin

		unique case(state)
			idle		: begin
				icache_pmem_resp = '0;
				icache_pmem_rdata = '0;
				dcache_pmem_resp = '0;
				dcache_pmem_rdata = '0;
				pmem_read_arbiter = '0;
				pmem_wdata_arbiter = '0;				
				pmem_write_arbiter = '0;
				pmem_address_arbiter = '0;
			end 

			icache_state : begin
				icache_pmem_resp = pmem_resp_arbiter;
				icache_pmem_rdata = pmem_rdata_arbiter;
				dcache_pmem_resp = '0;
				dcache_pmem_rdata = '0;
				pmem_read_arbiter = icache_pmem_read;
				pmem_wdata_arbiter = '0;
				pmem_write_arbiter = '0;
				pmem_address_arbiter = icache_pmem_address;
			end 

			dcache_state 	: begin 
				icache_pmem_resp = '0;
				icache_pmem_rdata = '0;
				dcache_pmem_resp = pmem_resp_arbiter;
				dcache_pmem_rdata = pmem_rdata_arbiter;
				pmem_read_arbiter = dcache_pmem_read;
				pmem_wdata_arbiter = dcache_pmem_wdata;				
				pmem_write_arbiter = dcache_pmem_write;
				pmem_address_arbiter = dcache_pmem_address;
			end 

			default		: begin
				icache_pmem_resp = '0;
				icache_pmem_rdata = '0;
				dcache_pmem_resp = '0;
				dcache_pmem_rdata = '0;
				pmem_read_arbiter = '0;
				pmem_write_arbiter = '0;
				pmem_address_arbiter = '0;
				pmem_wdata_arbiter = '0;				
			end 

		endcase 
	end

	always_comb begin

		next_state = state;

		unique case(state)
			idle: begin 
				if (icache_pmem_read)
					next_state = icache_state;
				else if (dcache_pmem_read || dcache_pmem_write)
					next_state = dcache_state;
				else
					next_state = idle;
			end 
			icache_state: begin
				if ((dcache_pmem_read || dcache_pmem_write) && pmem_resp_arbiter)
					next_state = dcache_state;
				else if (pmem_resp_arbiter)
					next_state = idle;
				else
					next_state = icache_state;
			end 
			dcache_state: begin
				if ((icache_pmem_read) && pmem_resp_arbiter && (~hold_arbiter))
					next_state = icache_state;
				else if (pmem_resp_arbiter && (~hold_arbiter))
					next_state = idle;
				else 
					next_state = dcache_state;
			end

			default: ;
		endcase 
	end

	always_ff @(posedge clk) begin
		if(rst) begin 
			state  <= idle;
		end 
		else begin 
			state  <= next_state;
		end
	end

endmodule : arbiter

