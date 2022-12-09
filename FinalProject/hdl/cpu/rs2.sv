/* Reservation station that stores three oprands
   For branch unit only
*/

module rs2
import rv32i_types::*;
#(
    parameter size = SIZE_RS_BR,
    parameter len_opc = LEN_OPC_BR,
    parameter len_id = LEN_ID
)
(
    input logic clk,
    input logic rst,

    // Issue
    input logic issue_en_rs2,
    input logic [len_opc-1:0] issue_opc_rs2,
    input logic [SIZE_GLOBAL-1:0] issue_br_history,
    output logic rs2_isfull,

    // ROB/Regfile
    input logic [len_id-1:0] rob_id,
    // Oprand 1
    input logic rs2_opr1_rdy,
    input logic [len_id-1:0] rs2_opr1_id,
    input logic [31:0] rs2_opr1_val,
    // Oprand 2
    input logic rs2_opr2_rdy,
    input logic [len_id-1:0] rs2_opr2_id,
    input logic [31:0] rs2_opr2_val,
    // Imm (always valid for br/jal/jalr)
    input logic [31:0] rs2_imm_val,
    // PC (always valid for br/jal/jalr)
    input logic [31:0] rs2_pc_val,

    // Execution unit
    input logic br_resp,               // 1-Line pointed by cursor_exe_i is executed
    input logic br_finish,             // 1-Result has been written to the bus
    output logic rs2_exe_req,            // 1-A line is ready to be executed
    output logic [len_id-1:0] rs2_id,
    output logic [len_opc-1:0] rs2_opc,
    output logic [31:0] rs2_opr1,
    output logic [31:0] rs2_opr2,
    output logic [31:0] rs2_imm,
    output logic [31:0] rs2_pc,
    output logic [SIZE_GLOBAL-1:0] rs2_br_history,

    // CDB
    input cdb_data cdb_data_out,
    input cdb_flush cdb_flush_out
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
// Imm, PC, br history
logic [size-1:0][31:0] imm_val, imm_val_n;
logic [size-1:0][31:0] pc_val, pc_val_n;
logic [size-1:0][SIZE_GLOBAL-1:0] br_hist, br_hist_n;

// Others Signals
logic [$clog2(size)-1:0] cursor_issue_i;              // Point to next available line
logic [$clog2(size)-1:0] cursor_exe_i;                // Point to next line to execute
logic cursor_exe_valid_i;           // 1-cursor_exe_i is valid

// Updata internal state (ff)
always_ff @(posedge clk) begin
    if (rst) begin
        valid <= {size{1'b0}};
    end
    else begin
        valid <= valid_n;
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
    pc_val <= pc_val_n;
    br_hist <= br_hist_n;
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
    pc_val_n = pc_val;
    br_hist_n = br_hist;

    for (int i=0; i<size; i++) begin
        /* Order of if-statements is important */
        // Start Executing
        if (br_resp && cursor_exe_valid_i && (i[$clog2(size)-1:0] == cursor_exe_i)) begin
            exe_n[i] = 1'b1;
            // Finish at same cycle
            if (br_finish)
                valid_n[i] = 1'b0;
        end

        // Finish Executing (aka result has been written to the bus)
        if (valid[i] && br_finish && exe[i]) begin
            valid_n[i] = 1'b0;
        end

        // Issue
        if (issue_en_rs2 && (i[$clog2(size)-1:0] == cursor_issue_i)) begin
            valid_n[i] = 1'b1;
            exe_n[i] = 1'b0;
            id_n[i] = rob_id;
            opc_n[i] = issue_opc_rs2;
            // opr1
            opr1_rdy_n[i] = rs2_opr1_rdy;
            opr1_id_n[i] = rs2_opr1_id;
            opr1_val_n[i] = rs2_opr1_val;
            // opr2
            opr2_rdy_n[i] = rs2_opr2_rdy;
            opr2_id_n[i] = rs2_opr2_id;
            opr2_val_n[i] = rs2_opr2_val;
            // opr3
            imm_val_n[i] = rs2_imm_val;
            pc_val_n[i] = rs2_pc_val;
            br_hist_n[i] = issue_br_history;
        end

        // Write
        if (cdb_data_out.valid) begin
            if ((valid[i] && opr1_id[i] == cdb_data_out.id && ~opr1_rdy[i])
                || (issue_en_rs2 && i[$clog2(size)-1:0] == cursor_issue_i && rs2_opr1_id == cdb_data_out.id && ~rs2_opr1_rdy)) begin
                opr1_rdy_n[i] = 1'b1;
                opr1_val_n[i] = cdb_data_out.data;
            end

            if ((valid[i] && opr2_id[i] == cdb_data_out.id && ~opr2_rdy[i])
                || (issue_en_rs2 && i[$clog2(size)-1:0] == cursor_issue_i && rs2_opr2_id == cdb_data_out.id && ~rs2_opr2_rdy)) begin
                opr2_rdy_n[i] = 1'b1;
                opr2_val_n[i] = cdb_data_out.data;
            end
        end

        // Flush
        if (cdb_flush_out.en && cdb_flush_out.en_id[id[i]]) begin
            valid_n[i] = 1'b0;
        end
    end
end

// Output
always_comb begin
    rs2_isfull = (& valid) & (~ br_finish);   // Similar logic to rob
    
    // Find a line to execute
    cursor_exe_i = {$clog2(size){1'b0}};
    cursor_exe_valid_i = 1'b0;
    for (int i=0; i<size; i++) begin
        if (valid[i] && (~ exe[i]) && opr1_rdy[i] && opr2_rdy[i]) begin
            cursor_exe_i = i[$clog2(size)-1:0];
            cursor_exe_valid_i = 1'b1;
            break;
        end
    end

    // Find a line to issue instruction
    cursor_issue_i = cursor_exe_i;
    for (int i=0; i<size; i++) begin
        if (~ valid[i]) begin       // Include line that is just finished? No
            cursor_issue_i = i[$clog2(size)-1:0];
            break;
        end
    end

    // Execute the line
    rs2_exe_req = cursor_exe_valid_i;
    rs2_id = id[cursor_exe_i];
    rs2_opc = opc[cursor_exe_i];
    rs2_opr1 = opr1_val[cursor_exe_i];
    rs2_opr2 = opr2_val[cursor_exe_i];
    rs2_imm = imm_val[cursor_exe_i];
    rs2_pc = pc_val[cursor_exe_i];
    rs2_br_history = br_hist[cursor_exe_i];
end


endmodule : rs2