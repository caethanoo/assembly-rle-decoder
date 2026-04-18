.intel_syntax noprefix

# =======================================================================
# PROJETO 1 - DECODIFICADOR RLE (x86-64 Linux)
# Sintaxe: Intel
# Compilação: gcc -Wall projeto.s -o projeto.elf -no-pie
#
# Variáveis locais (na pilha):
#   rbp - 4  : Maior valor de X lido (max_x)
#   rbp - 8  : Maior valor de Y lido (max_y)
#   rbp - 12 : Contador total de pixels desenhados
#   rbp - 16 : Largura lógica da imagem (max_x + 1)
#   rbp - 20 : Variável temporária para ler os valores (scanf buffer)
# =======================================================================

.section .rodata
fmt_hex:    .string "%x"      # Formato para leitura/escrita em Hex
fmt_dec:    .string "%d"      # Formato para leitura/escrita Decimal
fmt_char:   .string "%c"      # Formato para imprimir apenas um caractere na tela
fmt_taxa:   .string "[%d%%]\n"# Formato para apresentar a taxa de compressão
fmt_nl:     .string "\n"      # Quebra de linha

.section .bss
# Canvas onde a imagem reconstituida será escrita
.align 16
palette:    .space 16         # 16 bytes guardam a paleta ASCII (do index 0x0 a 0xF)
canvas:     .space 4096       # Espaço suficiente para nossa matriz/canvas (64x64px máx)
tuples:     .space 8192       # Espaço reservado para as tuplas 
                              # Cada tupla salva ocupará 16 bytes: [X, Y, COUNT, CHAR]
var_n:      .space 4          # Total de imagens
var_m:      .space 4          # Total de tuplas

.section .text
.global main
main:
    # Prólogo - Prepara a pilha de acordo com a System V ABI
    push rbp
    mov rbp, rsp
    sub rsp, 32                # Alinhamento perfeito em 16-bytes (rsp + 32)
    
    # Inicialização segura das variáveis em zero (max_x, max_y, total_pixels)
    mov dword ptr [rbp-4], 0
    mov dword ptr [rbp-8], 0
    mov dword ptr [rbp-12], 0
    
    # ----------------------------------------------------
    # ETAPA 1: LER A PALETA (16 BYTES HEX)
    # ----------------------------------------------------
    mov r12d, 0                # r12d = contador (i da paleta)
ler_paleta_loop:
    cmp r12d, 16               # Verifica se já lemos as 16 cores
    jge ler_n                  # Se i >= 16, vai para ler as imagens (n)
    
    lea rdi, [rip+fmt_hex]     # Parm1 (rdi) = Formato de leitura
    lea rsi, [rbp-20]          # Parm2 (rsi) = Ponteiro do buffer temporario
    xor eax, eax               # Varargs count (zero para scanf/printf)
    call scanf@plt             # Chamada para biblioteca C localizando PLT
    
    mov eax, dword ptr [rbp-20]# O valor guardado localmente na stack agora em EAX
    lea rdx, [rip+palette]   
    mov byte ptr [rdx+r12], al # Salva na memória .BSS
    inc r12d                   # Incrementa o iterator
    jmp ler_paleta_loop

    # ----------------------------------------------------
    # ETAPA 2: LER N (Qtd de imagens) E M (tuplas)
    # ----------------------------------------------------
ler_n:
    lea rdi, [rip+fmt_dec]
    lea rsi, [rip+var_n]
    xor eax, eax
    call scanf@plt
ler_m:
    lea rdi, [rip+fmt_dec]
    lea rsi, [rip+var_m]
    xor eax, eax
    call scanf@plt

    # ----------------------------------------------------
    # ETAPA 3: LER TUPLAS, ACHAR MAX_X e MAX_Y E ARMAZENAR NO BUFFER
    # ----------------------------------------------------
    mov r12d, 0                # Contador de tuplas (i = 0)
ler_tuplas_loop:
    cmp r12d, dword ptr [rip+var_m]
    jge preparar_canvas        # Quando lermos todas, avançamos
    
    # Ler X
    lea rdi, [rip+fmt_hex]
    lea rsi, [rbp-20]
    xor eax, eax
    call scanf@plt
    mov eax, dword ptr [rbp-20]# eax = X (Lido)
    
    # Atualizar max_x: se X > max_x: max_x = X
    cmp eax, dword ptr [rbp-4]
    jle set_x
    mov dword ptr [rbp-4], eax # Subscreve max_X
set_x:  
    mov r13d, eax              # Armazena X lido de fato em r13d
    
    # Ler Y
    lea rdi, [rip+fmt_hex]
    lea rsi, [rbp-20]
    xor eax, eax
    call scanf@plt
    mov eax, dword ptr [rbp-20]# eax = Y (Lido)
    
    # Atualizar max_y: se Y > max_y: max_y = Y
    cmp eax, dword ptr [rbp-8]
    jle set_y
    mov dword ptr [rbp-8], eax # Subscreve max_Y
set_y:
    mov r14d, eax              # Armazena Y lido em r14d
    
    # Ler B
    lea rdi, [rip+fmt_hex]
    lea rsi, [rbp-20]
    xor eax, eax
    call scanf@plt
    mov eax, dword ptr [rbp-20]# eax = B (Lido)
    
    # Calcular COUNT e o Total de Pixels (B >> 4)
    mov ecx, eax
    shr ecx, 4                 # Shift aritmético (Count agora está em ECX)
    add dword ptr [rbp-12], ecx# Soma total_pixels += count pra taxa futura
    
    # Calcular o Char na Paleta (B & 0xF)
    and eax, 15                # Mascara extraindo ultimos 4 bits
    lea rdx, [rip+palette]
    movzx eax, byte ptr [rdx+rax] # Extrai o CHAR correto mapeando da paleta 
    
    # Guarda os elementos processados no struct .BSS de cache (tuples struct)
    mov r15d, r12d
    shl r15d, 4                # r15d = index * 16 (4 propriedades dword = 16 bytes)
    lea rdx, [rip+tuples]
    add rdx, r15               # Ponteiro de base da tupla real iterada
    
    mov dword ptr [rdx], r13d    # Posição 0: coord X
    mov dword ptr [rdx+4], r14d  # Posição 4: coord Y
    mov dword ptr [rdx+8], ecx   # Posição 8: repetições count
    mov dword ptr [rdx+12], eax  # Posição 12: ASCII char escolhido
    
    inc r12d
    jmp ler_tuplas_loop

    # ----------------------------------------------------
    # ETAPA 4: PREPARAR O CANVAS LÓGICO COM OS ESPAÇOS E W_MAX
    # ----------------------------------------------------
preparar_canvas:
    # O comprimento máximo do Canvas precisa garantir a quebra dinâmica! (w = max_x + 1)
    mov eax, dword ptr [rbp-4] 
    inc eax                    # largura_maxima calculada!
    mov dword ptr [rbp-16], eax 
    
    # Limpar matriz linear global enchendo de espaços
    lea rdi, [rip+canvas]
    mov rcx, 4096              # Varre todos bytes pra evitar sobras do SO
    mov al, 0x20               # 0x20 = espaco
    rep stosb                  # Repete gravando byte (AL) vezes em [RDI]
    
    # ----------------------------------------------------
    # ETAPA 5: PINTAR OS PIXELS NO CANVAS USANDO LINEARIDADE / WRAP AUTOMÁTICO
    # ----------------------------------------------------
    mov r12d, 0                # i = 0 (resetar iterador de tuplas)
pintar_loop:
    cmp r12d, dword ptr [rip+var_m]
    jge imprimir_taxa
    
    mov r15d, r12d
    shl r15d, 4                # r15d = i * 16
    lea rdx, [rip+tuples]
    add rdx, r15               # Acessa ponteiro armazenado da struct atual da memória
    
    mov r13d, dword ptr [rdx]    # r13d = coord X inicial
    mov r14d, dword ptr [rdx+4]  # r14d = coord Y inicial
    mov ecx, dword ptr [rdx+8]   # ecx = repetições count
    mov eax, dword ptr [rdx+12]  # eax = ASCII character em si
    
    # Equação de offset linear que permitirá que o WRAP aconteça em cascata entre quebras
    # OFFSET BASE = Y * W + X 
    mov r15d, r14d
    imul r15d, dword ptr [rbp-16] # Posição Y da tupla * width
    add r15d, r13d                # E no final adiciona a coluna de onde o run começa
    
copia_caracteres:
    cmp ecx, 0                 # Terminou o tamanho das repetições (count)
    jle proxima_tupla
    
    lea rsi, [rip+canvas]
    mov byte ptr [rsi+r15], al # Carimba o byte ascii linearmente no final da fita
    
    inc r15d                   # Incrementa offset linear
    dec ecx                    # Subtrai contador de count repetiçao
    jmp copia_caracteres
    
proxima_tupla:
    inc r12d
    jmp pintar_loop

    # ----------------------------------------------------
    # ETAPA 6: MATEMÁTICA DA TAXA DE COMPRESSÃO E PRINT FINAL
    # ----------------------------------------------------
imprimir_taxa:
    # Equação requisitata: ((M * 3) * 100) / TOTAL_PIXELS_DESENHADOS
    mov eax, dword ptr [rip+var_m]
    imul eax, eax, 300         # Substitui dois Mults por x*300 ja que 3*100=300 
    xor edx, edx               # Zera a parte alta de EDX antes da divisão inteira
    mov ecx, dword ptr [rbp-12]# Total_pixels gerados na pilha via trackage inicial
    div ecx                    # Restam em EAX o resultado e EDX o resto
    
    lea rdi, [rip+fmt_taxa]
    mov esi, eax               # Move a string gerada pra RSI pra encaixar no formato
    xor eax, eax               # Varargs = 0
    call printf@plt

    # Loop externo por Y de 0 a max_y
    mov r12d, 0                # Iterator Y = 0
loop_y:
    cmp r12d, dword ptr [rbp-8]
    jg saia_do_programa
    
    # Loop interno por X de 0 a max_x
    mov r13d, 0                # Iterator X = 0
loop_x:
    cmp r13d, dword ptr [rbp-4]
    jg fim_da_linha_x
    
    # Localiza e carrega em al o valor Linear da coordenada 2D index[y*w + x]
    mov eax, r12d              
    imul eax, dword ptr [rbp-16] # EAX = y * largura_maxima
    add eax, r13d                # ... + x
    lea rdx, [rip+canvas]
    movzx esi, byte ptr [rdx+rax]# RSI <- caractere ASCII final do Canvas
    
    lea rdi, [rip+fmt_char]      # Prepara template pra cuspir pro terminal
    xor eax, eax
    call printf@plt
    
    inc r13d
    jmp loop_x

fim_da_linha_x:
    # Quebra de linha ao fim do eixo X
    lea rdi, [rip+fmt_nl]
    xor eax, eax
    call printf@plt            # Imprime new line
    
    inc r12d                   # Proxima linha de Y e reinicia
    jmp loop_y

saia_do_programa:
    mov eax, 0
    leave                      # Epilogo desfaz RBP e RSP
    ret