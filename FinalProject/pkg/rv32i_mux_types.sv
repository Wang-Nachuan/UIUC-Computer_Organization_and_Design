package rsoprmux;
typedef enum bit [2:0] {
    none    = 3'd0,     // No oprand
    sr      = 3'd1,     // Register
    pc      = 3'd2,     // PC
    i_imm   = 3'd3,     // I-immediate
    u_imm   = 3'd4,     // U-immediate
    b_imm   = 3'd5,     // B-immediate
    s_imm   = 3'd6,     // S-immediate
    j_imm   = 3'd7      // J-immediate
} rsoprmux_sel_t;
endpackage



