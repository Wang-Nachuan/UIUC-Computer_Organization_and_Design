module mp3
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

// Internal signals

// CPU memory signals
logic [31:0] mem_address;
logic [31:0] mem_rdata;
logic [31:0] mem_wdata;
logic mem_read;
logic mem_write;
logic [3:0] mem_byte_enable;
logic mem_resp;

// Cacheline adaptor signals
logic [31:0] cladpt_pmem_address;
logic [255:0] cladpt_pmem_rdata;
logic [255:0] cladpt_pmem_wdata;
logic cladpt_pmem_read;
logic cladpt_pmem_write;
logic cladpt_pmem_resp;

// Keep cpu named `cpu` for RVFI Monitor
// Note: you have to rename your mp2 module to `cpu`
cpu cpu(.*);

// Keep cache named `cache` for RVFI Monitor
cache cache(
    .pmem_address(cladpt_pmem_address),
    .pmem_rdata(cladpt_pmem_rdata),
    .pmem_wdata(cladpt_pmem_wdata),
    .pmem_read(cladpt_pmem_read),
    .pmem_write(cladpt_pmem_write),
    .pmem_resp(cladpt_pmem_resp),
    .*
);

// Cacheline adaptor
cacheline_adaptor cacheline_adaptor(
    .clk(clk),
    .reset_n(rst),
    // Port to LLC (Lowest Level Cache)
    .line_i(cladpt_pmem_wdata),
    .line_o(cladpt_pmem_rdata),
    .address_i(cladpt_pmem_address),
    .read_i(cladpt_pmem_read),
    .write_i(cladpt_pmem_write),
    .resp_o(cladpt_pmem_resp),
    // Port to memory
    .burst_i(pmem_rdata),
    .burst_o(pmem_wdata),
    .address_o(pmem_address),
    .read_o(pmem_read),
    .write_o(pmem_write),
    .resp_i(pmem_resp)
);

endmodule : mp3