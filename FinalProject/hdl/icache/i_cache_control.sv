
module i_cache_control 
import i_cache_types::*;
(
    input clk,
    input rst,

    // Inputs
    // CPU
    input mem_read,

    // Cache Datapath
    input hit,

    // lower_memory
    input pmem_resp_i,

    // Outputs
    // CPU
    output logic mem_resp,
    // Cache Datapth
    output i_write_data_selection write_data_selection_t,      
    output logic load,
    output i_write_enable_selection write_en_selection_t,       
    output logic valid,

    output logic load_lru,
    output i_address_selection address_selection_t,        
    // lower memory
    output logic pmem_read_t

);

// State Enum
// typedef enum logic[2:0] { IDLE, CHK_R, WRITEBACK, FETCH, CHK_W
// } State;
typedef enum logic[2:0] { IDLE, CHK_R, FETCH
} State;

State state, next_state;

always_ff @ (posedge clk, posedge rst) begin : FF_LOGIC
    if (rst) state <= IDLE;
    else     state <= next_state;
end

always_comb begin : NEXT_STATE_LOGIC
    next_state = state;

    case (state)
        IDLE: begin
            if (mem_read)                  next_state = CHK_R;
            // else if (mem_write)
            //     next_state = CHK_W;
        end
        CHK_R: begin
            if (hit) begin
                next_state = IDLE;
            end

            else                                       next_state = FETCH;
        end

        FETCH: begin
            if (pmem_resp_i)                            next_state = IDLE;
        end

        default: next_state = State'('x);
    endcase
end

always_comb begin : OUTPUT_LOGIC
    // Defaults
    mem_resp       = 1'b0;
    load           = 1'b0;
    write_data_selection_t = i_write_data_selection'(0);
    write_en_selection_t   = i_write_enable_selection'(0);
    valid          = 1'b0;

    load_lru       = 1'b0;
    address_selection_t   = i_address_selection'(0);
    pmem_read_t     = 1'b0;


    case (state)
        IDLE: begin
            ;// Defaults
        end
        CHK_R: begin
            if (hit) begin
                mem_resp = 1'b1;
                load_lru = 1'b1;
                
            end
        end
    

        FETCH: begin
            write_data_selection_t = LOWER_MEM_DATA;
            pmem_read_t     = 1'b1;
            if (pmem_resp_i) begin
                valid          = 1'b1;
                load           = 1'b1;
                write_en_selection_t   = ALL_ENABLE;
            end
        end

        default: begin
            mem_resp       = 'x;
            load           = 'x;
            write_data_selection_t = i_write_data_selection'('x);
            write_en_selection_t   = i_write_enable_selection'('x);
            valid          = 'x;

            load_lru       = 'x;
            address_selection_t   = i_address_selection'('x);
            pmem_read_t     = 'x;

        end
    endcase
end

endmodule : i_cache_control
