# art_backup

Originais da arte gerada, na resolução em que saíram (≈1254px), antes de virarem
os arquivos que o jogo usa.

Nada aqui é carregado pelo jogo. O `.gdignore` faz o Godot ignorar a pasta
inteira, então estes arquivos não são importados nem entram no build.

## Para que serve

Os arquivos em `assets/` são derivados destes: os tiles de chão viram 16x16 num
atlas, as decorações viram 16x16 ou props de 48x48, e os obstáculos viram 64x64.
Esse processo perde informação e não tem volta. Se um dia for preciso refazer um
tile com outra cor, outro tamanho ou outro tratamento, é daqui que se parte.

## Estrutura

- `snow/ground/` — as três texturas de terreno
- `snow/decorations/` — as oito decorações, mais a folha de contato original
- `snow/props/` — os quatro obstáculos grandes
