module arbiter( 
    input logic clk,
    input logic rst,
    // signal between instruction cache and the arbiter
    input logic i_mem_read,
    input logic [31:0] i_mem_addr,
    output logic [255:0] i_mem_data,
    output logic i_mem_resp,

    // signal between data cache and the arbiter
    input logic d_mem_read,
    input logic d_mem_write,
    input logic [255:0] d_mem_wdata,
    input logic [31:0] d_mem_addr,
    output logic [255:0] d_mem_rdata,
    output logic d_mem_resp,

    // signal between cacheline adaptor and the arbiter
    input logic pmem_resp_ca,
    output logic pmem_write_ca,
    output logic pmem_read_ca,
    output logic [31:0] pmem_address_ca,
    input logic[255:0] pmem_rdata_256_ca,
    output logic[255:0] pmem_wdata_256_ca
);

enum int unsigned {
    idle, 
    read_instruction,
    read_write_data
} state, next_states;



always_comb
begin : state_actions
    
    i_mem_data=256'b0;
    i_mem_resp=1'b0;
    d_mem_rdata=256'b0;
    d_mem_resp=1'b0;
    pmem_write_ca=1'b0;
    pmem_read_ca=1'b0;
    pmem_address_ca=32'b0;
    pmem_wdata_256_ca=256'b0;
    
    unique case (state)
        idle:begin
        end         
        read_instruction:begin
            pmem_read_ca=i_mem_read;
            pmem_address_ca=i_mem_addr;
            i_mem_data=pmem_rdata_256_ca;
            i_mem_resp=pmem_resp_ca;
        end 
        read_write_data:begin
            d_mem_resp=pmem_resp_ca;
            pmem_address_ca=d_mem_addr;
            if(d_mem_read)begin 
                pmem_read_ca=d_mem_read;
                d_mem_rdata=pmem_rdata_256_ca;
            end 
            else if(d_mem_write) begin  
                pmem_write_ca=d_mem_write;
                pmem_wdata_256_ca=d_mem_wdata;
            end
        end
    endcase
end

always_comb
begin : next_state_logic
    unique case (state)
        idle:begin
            //firstly we let data cache has the priority over instruction cache
            if(d_mem_read||d_mem_write) next_states=read_write_data;
            else if(i_mem_read) next_states=read_instruction;
            else next_states=idle;
        end
        read_instruction:begin
            if(pmem_resp_ca) next_states=idle;
            else next_states=read_instruction;
        end
        read_write_data:begin
            if(pmem_resp_ca) next_states=idle;
            else next_states=read_write_data;
        end
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    if (rst) begin
        state <= idle;
    end
    else begin 
        state <= next_states;
    end
end

endmodule:arbiter