/* MODIFY. The cache controller. It is a state machine
that controls the behavior of the cache. */

module cache_control #(
    parameter asso = 2,         // Associative
    parameter asso_log = 1      // Log associative
)
(
    input clk,
    input rst,

    /* From/To datapath */
    // Valid
    output  logic [asso-1:0]    ld_valid,
    output  logic [asso-1:0]    valid_in,
    // input   logic [asso-1:0]    valid_out,
    // Dirty
    output  logic [asso-1:0]    ld_dirty,
    output  logic [asso-1:0]    dirty_in,
    input   logic [asso-1:0]    dirty_out,
    // Tage
    output  logic [asso-1:0]    ld_tag,
    // Data
    output  logic               datainmux_sel,
    output  logic [asso_log-1:0]    dataoutmux_sel,
    output  logic [asso-1:0][1:0]   datamaskmux_sel,
    // LRU
    output  logic               ld_lru,
    output  logic               lru_in,
    input   logic               lru_out,
    // Other
    output  logic               ld_data_writeback,
    output  logic               ld_addr_writeback,
    input   logic               is_hit,
    input   logic               is_full,
    input   logic[asso-1:0]     is_way_hit,
    output  logic               paddrmux_sel,

    /* From/To CPU */
    input   logic               mem_read,
    input   logic               mem_write,
    output  logic               mem_resp,

    /* From/To memory */
    input   logic               pmem_resp,
    output  logic               pmem_read,
    output  logic               pmem_write
);

enum int unsigned {
    Idle,
    Hit,
    Miss,
    WriteBack
} state, next_state;

always_ff @(posedge clk) begin
    if (rst)
        state <= Idle;
    else
        state <= next_state;
end

/*-------------------------State Transition-------------------------*/

always_comb begin
    next_state = state;
    unique case (state)

        Idle: begin
            if (mem_read || mem_write)
                next_state = Hit;
        end

        Hit: begin
            if (is_hit)
                next_state = Idle;
            else
                next_state = Miss;
        end

        Miss: begin
            if (pmem_resp)
                if (is_full && dirty_out[lru_out]) next_state = WriteBack;
                else next_state = Hit;
        end

        WriteBack: begin
            if (pmem_resp) next_state = Hit;
        end

    endcase
end

/*--------------------------State Output--------------------------*/

always_comb begin
    ld_valid = 2'b0;
    valid_in = 2'b0;
    ld_dirty = 2'b0;
    dirty_in = 2'b0;
    ld_tag = 2'b0;
    datainmux_sel = 1'b0;
    dataoutmux_sel = 1'b0;
    datamaskmux_sel[0] = 2'b0;
    datamaskmux_sel[1] = 2'b0;
    ld_lru = 1'b0;
    lru_in = 1'b0;
    ld_data_writeback = 1'b0;
    ld_addr_writeback = 1'b0;
    paddrmux_sel = 1'b0;
    mem_resp = 1'b0;
    pmem_read = 1'b0;
    pmem_write = 1'b0;
    unique case (state)

        Idle: ;

        Hit: begin
            if (is_hit) begin
                // Respond to CPU
                mem_resp = 1'b1;
                // Update LRU record
                ld_lru = 1'b1;
                lru_in = is_way_hit[0];
                // Do different things
                if (mem_read)   // Assume that read/write won't happen at same time
                    dataoutmux_sel = is_way_hit[1];
                else begin
                    // Updata data array
                    datainmux_sel = 1'b1;
                    datamaskmux_sel[is_way_hit[1]] = 2'b10;
                    // Updata dirty bit
                    ld_dirty[is_way_hit[1]] = 1'b1;
                    dirty_in[is_way_hit[1]] = 1'b1;
                end
            end
        end

        Miss: begin
            // Read from main memory
            paddrmux_sel = 1'b0;
            pmem_read = 1'b1;
            // When data is available
            if (pmem_resp) begin
                // Load the new line
                datainmux_sel = 1'b0;
                datamaskmux_sel[lru_out] = 2'b01;
                // Update tag
                ld_tag[lru_out] = 1'b1;
                // Reset dirty bit
                ld_dirty[lru_out] = 1'b1;
                dirty_in[lru_out] = 1'b0;
                if (is_full) begin  // Eviction
                    if (dirty_out[lru_out]) begin
                        // Preserve evicted line and its address
                        ld_data_writeback = 1'b1;
                        ld_addr_writeback = 1'b1;  
                        dataoutmux_sel = lru_out;
                    end
                end
                else begin
                    // Set valid bit
                    ld_valid[lru_out] = 1'b1;
                    valid_in[lru_out] = 1'b1;
                end
            end
        end

        WriteBack: begin
            pmem_write = 1'b1;
            paddrmux_sel = 1'b1;
        end
        
    endcase
end


endmodule : cache_control
