extends RefCounted
class_name PixelText
## Ajustes de texto para a fonte pixelada do jogo (Press Start 2P).
##
## Ela não tem forma maiúscula própria para vogais acentuadas: "Ísis" sai com um
## "í" minúsculo no meio da palavra, e "RUÍNAS" vira "RUíNAS". Só "Ã", "Õ" e "Ç"
## sobrevivem. Aqui as vogais sem forma perdem o acento, o que lê muito melhor
## do que a minúscula deslocada.

const UNSUPPORTED_UPPERCASE := {
	"Á": "A", "À": "A", "Â": "A",
	"É": "E", "Ê": "E",
	"Í": "I",
	"Ó": "O", "Ô": "O",
	"Ú": "U",
}


## Mantém a caixa original e só troca as maiúsculas acentuadas sem glifo.
static func fit(text: String) -> String:
	var result := text
	for accented in UNSUPPORTED_UPPERCASE:
		result = result.replace(accented, UNSUPPORTED_UPPERCASE[accented])
	return result


## Caixa alta segura para a fonte pixelada.
static func upper(text: String) -> String:
	return fit(text.to_upper())
