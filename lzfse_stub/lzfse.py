"""Compatibilidad LZFSE para los servicios de Ojo GPS que no usan compresion."""


def compress(_data: bytes) -> bytes:
    raise RuntimeError("La compresion LZFSE no esta disponible en Ojo GPS")


def decompress(_data: bytes) -> bytes:
    raise RuntimeError("La descompresion LZFSE no esta disponible en Ojo GPS")
