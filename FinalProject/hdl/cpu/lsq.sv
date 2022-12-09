/* Reservation station that stores three oprands
   For memory unit only
*/

module lsq
import rv32i_types::*;
#(
    parameter size = SIZE_RS_LSQ,
    parameter len_opc = LEN_OPC_LSQ,
    parameter len_id = LEN_ID
)
(
    input logic clk,
    input logic rst,

    // Issue
    input logic issue_en_lsq,
    input logic [len_opc-1:0] issue_opc_lsq,
    output logic lsq_isfull,

    // ROB/Regfile
    input logic [len_id-1:0] rob_id,
    // Oprand 1
    input logic lsq_opr1_rdy,
    input logic [len_id-1:0] lsq_opr1_id,
    input logic [31:0] lsq_opr1_val,
    // Oprand 2
    input logic lsq_opr2_rdy,
    input logic [len_id-1:0] lsq_opr2_id,
    input logic [31:0] lsq_opr2_val,
    // Imm
    input logic [31:0] lsq_imm_val,

    // ROB
    input logic commit_lsq_en,
    input logic [$clog2(SIZE_ROB)-1:0] commit_lsq_id,

    // Memory
    input logic data_mem_resp,
    input rv32i_word data_mem_rdata,
    output logic data_read,
    output logic data_write,
    output logic [3:0] data_mbe,
    output rv32i_word data_mem_address,
    output rv32i_word data_mem_wdata,

    // CDB
    // input logic cdb_ctrl_resp_lsq,
    input cdb_data cdb_data_out,
    input cdb_flush cdb_flush_out,
    output cdb_data lsq_data_out
);

// Internal state
logic [size-1:0] valid, valid_n;
logic [size-1:0] exe, exe_n;
logic [size-1:0][len_id-1:0] id, id_n;
logic [size-1:0][len_opc-1:0] opc, opc_n;           // Opcode of specific operation
// Oprand 1
logic [size-1:0] opr1_rdy, opr1_rdy_n;              // 1-Use opr1_val/0-Use opr1_id
logic [size-1:0][len_id-1:0] opr1_id, opr1_id_n;
logic [size-1:0][31:0] opr1_val, opr1_val_n;
// Oprand 2
logic [size-1:0] opr2_rdy, opr2_rdy_n;
logic [size-1:0][len_id-1:0] opr2_id, opr2_id_n;
logic [size-1:0][31:0] opr2_val, opr2_val_n;
// Immediate value
logic [size-1:0][31:0] imm_val, imm_val_n;
// Execution
logic [$clog2(size)-1:0] cursor_exe, cursor_exe_n;
logic cursor_exe_valid, cursor_exe_valid_n;
// Buffer memory data
// logic [31:0] buff_data, buff_data_n;
// logic buff_data_valid, buff_data_valid_n;

// Others Signals
logic [$clog2(size)-1:0] cursor_issue_i;    // Point to next available line
logic exe_finish;

logic [31:0] addr_i;
logic [31:0] rdata_i, rdata_shift_i;
logic [31:0] wdata_i, wdata_shift_i;

// Updata internal state (ff)
always_ff @(posedge clk) begin
    if (rst) begin
        valid <= {size{1'b0}};
        cursor_exe_valid <= 1'b0;
    end
    else begin
        valid <= valid_n;
        cursor_exe_valid <= cursor_exe_valid_n;
    end

    exe <= exe_n;
    id <= id_n;
    opc <= opc_n;
    opr1_rdy <= opr1_rdy_n;
    opr1_id <= opr1_id_n;
    opr1_val <= opr1_val_n;
    opr2_rdy <= opr2_rdy_n;
    opr2_id <= opr2_id_n;
    opr2_val <= opr2_val_n;
    imm_val <= imm_val_n;
    cursor_exe <= cursor_exe_n;
    // buff_data <= buff_data_n;
    // buff_data_valid <= buff_data_valid_n;
end

// Updata internal state (comb)
always_comb begin
    // Default
    valid_n = valid;
    exe_n = exe;
    id_n = id;
    opc_n = opc;
    opr1_rdy_n = opr1_rdy;
    opr1_id_n = opr1_id;
    opr1_val_n = opr1_val;
    opr2_rdy_n = opr2_rdy;
    opr2_id_n = opr2_id;
    opr2_val_n = opr2_val;
    imm_val_n = imm_val;
    cursor_exe_n = cursor_exe;
    cursor_exe_valid_n = cursor_exe_valid;
    // buff_data_n = buff_data;
    // buff_data_valid_n = buff_data_valid;

    for (int i=0; i<size; i++) begin
        /* Order of if-statements is important */
        // Start Executing
        if (valid[i] && commit_lsq_en && id[i] == commit_lsq_id && ~exe[i]) begin
            exe_n[i] = 1'b1;
            cursor_exe_n = i[$clog2(size)-1:0];
            cursor_exe_valid_n = 1'b1;
            // buff_data_valid_n = 1'b0;
            // Finish at same cycle
            if (exe_finish) begin
                valid_n[i] = 1'b0;
                cursor_exe_valid_n = 1'b0;
                // buff_data_n = data_mem_rdata;
                // buff_data_valid_n = 1'b1;
            end
        end

        // Finish Executing (aka result has been written to the bus)
        if (valid[i] && exe_finish && exe[i]) begin
            valid_n[i] = 1'b0;
            cursor_exe_valid_n = 1'b0;
            // buff_data_n = data_mem_rdata;
            // buff_data_valid_n = 1'b1;
        end

        // Issue
        if (issue_en_lsq && (i[$clog2(size)-1:0] == cursor_issue_i)) begin
            valid_n[i] = 1'b1;
            exe_n[i] = 1'b0;
            id_n[i] = rob_id;
            opc_n[i] = issue_opc_lsq;
            // opr1
            opr1_rdy_n[i] = lsq_opr1_rdy;
            opr1_id_n[i] = lsq_opr1_id;
            opr1_val_n[i] = lsq_opr1_val;
            // opr2
            opr2_rdy_n[i] = lsq_opr2_rdy;
            opr2_id_n[i] = lsq_opr2_id;
            opr2_val_n[i] = lsq_opr2_val;
            // opr3
            imm_val_n[i] = lsq_imm_val;
        end

        // Write
        if (cdb_data_out.valid) begin
            if ((valid[i] && opr1_id[i] == cdb_data_out.id && ~opr1_rdy[i])
                || (issue_en_lsq && i[$clog2(size)-1:0] == cursor_issue_i && lsq_opr1_id == cdb_data_out.id && ~lsq_opr1_rdy)) begin
                opr1_rdy_n[i] = 1'b1;
                opr1_val_n[i] = cdb_data_out.data;
            end

            if ((valid[i] && opr2_id[i] == cdb_data_out.id && ~opr2_rdy[i])
                || (issue_en_lsq && i[$clog2(size)-1:0] == cursor_issue_i && lsq_opr2_id == cdb_data_out.id && ~lsq_opr2_rdy)) begin
                opr2_rdy_n[i] = 1'b1;
                opr2_val_n[i] = cdb_data_out.data;
            end

            // opr3 always stores imm value, so no write is needed
        end

        // Flush
        if (cdb_flush_out.en && cdb_flush_out.en_id[id[i]]) begin
            valid_n[i] = 1'b0;
        end
    end
end

// Output and other signSals
always_comb begin
    exe_finish = data_mem_resp;
    lsq_isfull = (& valid) & (~ exe_finish);   // Similar logic to rob
    addr_i = opr1_val[cursor_exe] + imm_val[cursor_exe];
    wdata_i = opr2_val[cursor_exe];
    wdata_shift_i = wdata_i << ('d8 * addr_i[1:0]);
    rdata_i = data_mem_rdata;
    rdata_shift_i = rdata_i >> ('d8 * addr_i[1:0]);

    // Find a line to issue instruction
    cursor_issue_i = cursor_exe;
    for (int i=0; i<size; i++) begin
        if (~ valid[i]) begin       // Include line that is just finished? No
            cursor_issue_i = i[$clog2(size)-1:0];
            break;
        end
    end

    // Generate memory signals
    data_read = 1'b0;
    data_write = 1'b0;
    data_mbe = 4'b1111;
    data_mem_address = {addr_i[31:2], 2'b00};
    data_mem_wdata = wdata_shift_i;
    if (cursor_exe_valid) begin
        case (opc[cursor_exe])
            ls_lb, ls_lh, ls_lw, ls_lbu, ls_lhu: data_read = 1'b1;
            ls_sb: begin
                data_write = 1'b1;
                data_mbe = 4'b0001 << addr_i[1:0];
            end
            ls_sh: begin
                data_write = 1'b1;
                data_mbe = 4'b0011 << addr_i[1:0];
            end
            ls_sw: data_write = 1'b1;
        endcase
    end
    
    // Write to CDB (has highest priority)
    lsq_data_out.valid = exe_finish;
    lsq_data_out.data = rdata_shift_i;
    lsq_data_out.id = id[cursor_exe];
    case (opc[cursor_exe])
        ls_lb:  lsq_data_out.data = {{24{rdata_shift_i[7]}}, rdata_shift_i[7:0]};
        ls_lbu: lsq_data_out.data = {24'b0, rdata_shift_i[7:0]};
        ls_lh:  lsq_data_out.data = {{16{rdata_shift_i[15]}}, rdata_shift_i[15:0]};
        ls_lhu: lsq_data_out.data = {16'b0, rdata_shift_i[15:0]};
        ls_lw:;
        ls_sb, ls_sh, ls_sw:;
    endcase
end


endmodule : lsq