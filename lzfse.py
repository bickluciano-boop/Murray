"""Compatibilidad minima para Ojo GPS.

El tunel TCP y la simulacion DVT no usan compresion LZFSE. Este modulo evita
que servicios opcionales impidan cargar pymobiledevice3 en Python 3.13/Windows.
"""


def compress(_data: bytes) -> bytes:
    raise RuntimeError("La compresion LZFSE no esta disponible en Ojo GPS")


def decompress(_data: bytes) -> bytes:
    raise RuntimeError("La descompresion LZFSE no esta disponible en Ojo GPS")
