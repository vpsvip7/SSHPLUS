#!/usr/bin/env python3
"""Test de velocidad para VPS (Ubuntu 20, Python 3.8+). Sin dependencias externas.

Uso:
    python3 speedtest_vps.py
    python3 speedtest_vps.py --mb 200 --hilos 4
"""
import argparse
import os
import socket
import threading
import time
import urllib.request

DOWN_URL = "https://speed.cloudflare.com/__down?bytes={bytes}"
UP_URL = "https://speed.cloudflare.com/__up"
PING_HOST = ("1.1.1.1", 443)
UA = {"User-Agent": "Mozilla/5.0 speedtest-vps"}


def ping(n=5):
    tiempos = []
    for _ in range(n):
        t = time.perf_counter()
        try:
            with socket.create_connection(PING_HOST, timeout=3):
                tiempos.append((time.perf_counter() - t) * 1000)
        except OSError:
            pass
        time.sleep(0.2)
    return tiempos


def _bajar(bytes_, resultado, i):
    req = urllib.request.Request(DOWN_URL.format(bytes=bytes_), headers=UA)
    total = 0
    with urllib.request.urlopen(req, timeout=30) as r:
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            total += len(chunk)
    resultado[i] = total


def descarga(mb, hilos):
    por_hilo = mb * 1024 * 1024 // hilos
    res = [0] * hilos
    ts = [threading.Thread(target=_bajar, args=(por_hilo, res, i)) for i in range(hilos)]
    t0 = time.perf_counter()
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    dt = time.perf_counter() - t0
    return sum(res) * 8 / dt / 1e6  # Mbps


def _subir(data, resultado, i):
    req = urllib.request.Request(UP_URL, data=data, headers=UA, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        r.read()
    resultado[i] = len(data)


def subida(mb, hilos):
    por_hilo = mb * 1024 * 1024 // hilos
    data = os.urandom(por_hilo)
    res = [0] * hilos
    ts = [threading.Thread(target=_subir, args=(data, res, i)) for i in range(hilos)]
    t0 = time.perf_counter()
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    dt = time.perf_counter() - t0
    return sum(res) * 8 / dt / 1e6  # Mbps


def main():
    p = argparse.ArgumentParser(description="Test de velocidad VPS")
    p.add_argument("--mb", type=int, default=100, help="MB a descargar (default 100)")
    p.add_argument("--subida-mb", type=int, default=25, help="MB a subir (default 25)")
    p.add_argument("--hilos", type=int, default=4, help="Conexiones paralelas (default 4)")
    a = p.parse_args()

    print("== Test de velocidad VPS ==")

    t = ping()
    if t:
        print(f"Ping:     {sum(t)/len(t):.1f} ms (min {min(t):.1f} / max {max(t):.1f})")
    else:
        print("Ping:     sin respuesta")

    try:
        print(f"Descarga: {descarga(a.mb, a.hilos):.1f} Mbps")
    except Exception as e:
        print(f"Descarga: error ({e})")

    try:
        print(f"Subida:   {subida(a.subida_mb, a.hilos):.1f} Mbps")
    except Exception as e:
        print(f"Subida:   error ({e})")


if __name__ == "__main__":
    main()
