import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    print("Probando conexion SSH a 10.160.10.114...")
    client.connect('10.160.10.114', username='root', password='root', timeout=5)
    stdin, stdout, stderr = client.exec_command('ip -br a')
    print("Salida ip -br a:")
    print(stdout.read().decode())
    client.close()
except Exception as e:
    print("Error:", e)
