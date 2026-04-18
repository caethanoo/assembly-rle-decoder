# Projeto 1 - Decodificador RLE (ASCII) em Assembly x86-64

Este projeto é um decodificador de imagens comprimidas usando Run-Length Encoding (RLE) escrito **inteiramente em Assembly puro (AMD64 / x86-64)** na sintaxe Intel. Ele interpreta tuplas contendo informações de repetição e cor, estruturando-as em uma grade bidimensional de caracteres ASCII perfeitamente dimensionada.

Desenvolvido como projeto para o aprendizado prático na disciplina de **IHS (Interface de Hardware e Software)**.

## 🚀 Como Compilar e Executar

Este código não exige dependências extras, sendo construído e linkado diretamente com a biblioteca padrão do C (`libc`) através do GCC no Linux.

**1. Compilar o código fonte:**
```bash
gcc projeto.s -o projeto.elf -no-pie
```

**2. Executar o programa injetando o input:**
```bash
./projeto.elf < image2ascii.input
```

# assembly-rle-decoder
