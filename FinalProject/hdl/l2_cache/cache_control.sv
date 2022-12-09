// This module contains state machine of the cache
module l2_cache_control 
import l2_d_cache_types::*;
(
    input clk,
    input rst,
    // Inputs
    // CPU
    input mem_read,
    input mem_write,
    // Cache Datapath
    input hit,
    input [num_ways-1:0] dirty_out,
    input [width-1:0] evicting_way,
    // Lower Memory
    input pmem_resp_i,

    // Outputs
    // CPU
    output logic mem_resp,
    // Cache Datapath
    output d_write_data_selection write_data_selection_t,      
    output logic load,
    output d_write_enable_selection write_en_selection_t,        
    output logic valid,
    output logic dirty,
    output logic load_lru,
    output d_address_selection d_address_selection_t,        
    output logic load_buffer,
    output logic write_back_busy,
    // Lower Memory
    output logic pmem_read_t,
    output logic pmem_write_t,
    output logic hold_arbiter
);

//logic write_back_busy;
logic preparing_write_back;
logic load_busy;
logic busy_in;
//logic hold_arbiter;

typedef enum logic[2:0] { IDLE, CHK_R, WRITEBACK, REGLOAD, FETCH, CHK_W
} State;

State state, next_state;

always_ff @ (posedge clk, posedge rst) begin
    if (rst) state <= IDLE;
    else     state <= next_state;
end

always_ff @ (posedge clk, posedge rst) begin
    if (rst) begin

        write_back_busy <= '0;
    end
    else if (load_busy) begin

        write_back_busy <= busy_in;
    end
end


// busy_reg busyreg(
//     .clk(clk),
//     .rst(rst),
//     .load_busy(load_busy),
//     .busy_in(busy_in),
//     .busy_out(write_back_busy)
// );

always_comb begin : state_transition_logic
    next_state = state;

    case (state)
        IDLE: begin
            if (mem_read)                  next_state = CHK_R;
            else if (mem_write)
                next_state = CHK_W;
        end
        CHK_R: begin
            if (hit) begin
                    next_state = IDLE;
            end
            else begin
		if (~dirty_out[evicting_way]) begin
                    if (write_back_busy) begin
                        next_state = CHK_R;
                    end
                    else begin
                        next_state = FETCH;
		    end
                end
                else  begin                              
			if (write_back_busy) begin

				next_state=CHK_R;
			end
			else begin
				next_state = WRITEBACK;
			end

		    end
	    end
        end

        //this state prepares for write_back and load the evicted data into register
        WRITEBACK: begin

            //prevent other new physical memory request while the previous writeback has not finished
            if (write_back_busy) begin
                next_state = WRITEBACK;
            end

            
            else begin
                        next_state = FETCH;
            end
        end

        //this state make the register write into physical memory;
        //this only lasts for one cycle and other new read/write hit can be served
        REGLOAD: begin
            next_state = IDLE;
        end
        
        FETCH: begin
            if (pmem_resp_i) begin                   
                if (preparing_write_back ==1'b1) begin
                    next_state =REGLOAD;
                end
            else begin
                next_state = IDLE;
            end
	        end
            end
        CHK_W: begin
            if (hit)                                   next_state = IDLE;
            else begin
		if (~dirty_out[evicting_way]) begin
                    if (write_back_busy) begin
                        next_state = CHK_W;
                    end
                    else begin
                        next_state = FETCH;
		    end
                end

                else begin 
			
			if (write_back_busy) begin

				next_state=CHK_W;
			end
			else begin
				next_state = WRITEBACK;
			end
			

	    	end
	    end
        end
        default: next_state = State'('x);
    endcase
end



always_comb begin : OUTPUT_LOGIC


		//test_signal=1'b0;
        load_busy =1'b0;
            busy_in=1'b0;

	hold_arbiter=1'b0;

    if (rst) begin
	    mem_resp       = 1'b0;
	    load           = 1'b0;
	    valid          = 1'b0;
	    dirty          = 1'b0;
	    //hold_arbiter   = 1'b0;
	    load_lru       = 1'b0;
	    pmem_read_t     = 1'b0;
	    pmem_write_t    = 1'b0;
	    //write_back_busy =1'b0;
	    preparing_write_back=1'b0;
	    load_buffer =1'b0;
        //load_busy =1'b0;
        //busy_in =1'b0;
    	write_data_selection_t = d_write_data_selection'(0);
	    write_en_selection_t   = d_write_enable_selection'(0);
	    d_address_selection_t   = d_address_selection'(0);

    end
    else begin
	    mem_resp       = 1'b0;
	    load           = 1'b0;
	    valid          = 1'b0;
	    dirty          = 1'b0;
	    load_lru       = 1'b0;
	    //d_address_selection_t   = d_address_selection'(0);
	    pmem_read_t     = 1'b0;
	    //pmem_write_t    = 1'b0;
	    //write_back_busy =1'b0;
	    load_buffer =1'b0;
        write_data_selection_t = d_write_data_selection'(0);
	    write_en_selection_t   = d_write_enable_selection'(0);
    end
    case (state)
        IDLE: begin
            ;
        end
        CHK_R: begin
            if (hit) begin
                mem_resp = 1'b1;
                load_lru = 1'b1;
                

            end
        end


        WRITEBACK: begin
            
            load_buffer=1'b1;
            
            preparing_write_back=1'b1;
            hold_arbiter=1'b1;
        end
        REGLOAD: begin
            //write_back_busy=1'b1;
            d_address_selection_t = LOWER_MEM_ADDRESS;
            preparing_write_back=1'b0;
            load_busy=1'b0;
        end

        FETCH: begin
            // load           = 1'b1;
            // valid          = 1'b1;
            pmem_read_t     = 1'b1;

            // write_en_selection_t   = ALL_ENABLE;
            if (pmem_resp_i == 1'b1) begin
                load           = 1'b1;
                valid          = 1'b1;
                write_en_selection_t   = ALL_ENABLE;
            	write_data_selection_t = LOWER_MEM_DATA;
                if (preparing_write_back == 1'b1) begin
                    load_busy =1'b1;
                    busy_in =1'b1;
                end
            end
        end
        CHK_W: begin
            if (hit) begin
                mem_resp       = 1'b1;
                load_lru       = 1'b1;
                load           = 1'b1;
                valid          = 1'b1;
                dirty          = 1'b1;
                write_data_selection_t = CPU_DATA;
                write_en_selection_t   = CPU_ENABLE;
            end

        end
        default: begin
            mem_resp       = 'x;
            load           = 'x;
            valid          = 'x;
            dirty          = 'x;
            load_lru       = 'x;
            pmem_read_t     = 'x;
            pmem_write_t    = 'x;
            load_busy ='x;
            busy_in ='x;
            //write_back_busy = 'x;
            write_data_selection_t = d_write_data_selection'('x);
            write_en_selection_t   = d_write_enable_selection'('x);
            d_address_selection_t   = d_address_selection'('x);
	        load_buffer = 'x;
        end
    endcase

    if (write_back_busy == 1'b1) begin

        if (pmem_resp_i == 1'b1) begin
            busy_in=1'b0;
            load_busy=1'b1;
            pmem_write_t=1'b0;
            d_address_selection_t=CPU_ADDRESS;
            hold_arbiter=1'b0;
        end
        else begin
            pmem_write_t=1'b1;
		load_busy=1'b0;
	        d_address_selection_t=LOWER_MEM_ADDRESS;
		    hold_arbiter=1'b1;
        end

    end
    
    else begin
        pmem_write_t=1'b0;
	    d_address_selection_t=CPU_ADDRESS;
		    //hold_arbiter='0;
    end

end


endmodule : l2_cache_control


