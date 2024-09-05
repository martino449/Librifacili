import json
from Crypto.Cipher import AES
import base64

# Modulo per la crittografia dei dati
class Criptografia:
    ALGORITMO = 'AES'
    KEY = b'12345678901234561234567890123456'
    IV = b'1234567890123456'

    @staticmethod
    def cifra(dati):
        cipher = AES.new(Criptografia.KEY, AES.MODE_CBC, Criptografia.IV)
        padding = 16 - len(dati) % 16
        dati_padded = dati + chr(padding) * padding
        encrypted = cipher.encrypt(dati_padded.encode('utf-8'))
        return base64.b64encode(encrypted).decode('utf-8')

    @staticmethod
    def decifra(dati):
        decipher = AES.new(Criptografia.KEY, AES.MODE_CBC, Criptografia.IV)
        decoded = base64.b64decode(dati)
        decrypted = decipher.decrypt(decoded).decode('utf-8')
        padding = ord(decrypted[-1])
        return decrypted[:-padding]

# Classe che rappresenta un utente
class Utente:
    def __init__(self, username, password, crediti=0, ruolo='user'):
        self.username = username
        self.password = password
        self.crediti = crediti
        self.ruolo = ruolo

    def authenticate(self, password):
        return self.password == password

    def guadagna_credito(self, amount):
        self.crediti += amount

    def spende_credito(self, amount):
        if self.crediti >= amount:
            self.crediti -= amount
            return True
        return False

    def to_dict(self):
        return {
            'username': self.username,
            'password': self.password,
            'crediti': self.crediti,
            'ruolo': self.ruolo
        }

    @staticmethod
    def from_dict(data):
        return Utente(data['username'], data['password'], data['crediti'], data['ruolo'])

# Classe per gestire il sistema degli utenti
class SistemaGestioneUtenti:
    def __init__(self):
        self.utenti = {}

    def register(self, username, password, ruolo='user'):
        if username in self.utenti:
            return "Username già esistente. Scegli un altro username."
        self.utenti[username] = Utente(username, password, 0, ruolo)
        return "Registrazione avvenuta con successo! Puoi ora effettuare il login."

    def login(self, username, password):
        utente = self.utenti.get(username)
        if utente and utente.authenticate(password):
            return utente
        return None

    def list_users(self):
        if not self.utenti:
            return "Nessun utente registrato."
        return "\n".join([f"{username} - Crediti: {utente.crediti}" for username, utente in self.utenti.items()])

    def to_json(self):
        return json.dumps([utente.to_dict() for utente in self.utenti.values()])

    @staticmethod
    def from_json(json_str):
        sistema = SistemaGestioneUtenti()
        utenti_data = json.loads(json_str)
        for utente_data in utenti_data:
            sistema.utenti[utente_data['username']] = Utente.from_dict(utente_data)
        return sistema

    def save_to_file(self, filename):
        dati = self.to_json()
        encrypted_dati = Criptografia.cifra(dati)
        with open(filename, 'w') as file:
            file.write(encrypted_dati)

    @staticmethod
    def load_from_file(filename):
        try:
            with open(filename, 'r') as file:
                encrypted_dati = file.read()
                dati = Criptografia.decifra(encrypted_dati)
                return SistemaGestioneUtenti.from_json(dati)
        except FileNotFoundError:
            return SistemaGestioneUtenti()

# Classe per gestire la libreria
class Libreria:
    def __init__(self):
        self.libri = []
        self.prestiti = {}

    def add_book(self, libro):
        self.libri.append(libro)

    def list_books(self):
        if not self.libri:
            return "Nessun libro disponibile."
        return "\n".join([str(libro) for libro in self.libri])

    def list_borrowed_books(self):
        if not self.prestiti:
            return "Nessun libro è stato prestato."
        return "\n".join([f"{username}: {', '.join(libri)}" for username, libri in self.prestiti.items()])

    def borrow_book(self, username, titolo):
        libro = next((libro for libro in self.libri if libro.titolo == titolo), None)
        if libro:
            utente = SistemaGestioneUtenti.load_from_file('utenti.json').login(username, '')
            if utente:
                if utente.spende_credito(1):
                    if username in self.prestiti:
                        self.prestiti[username].append(titolo)
                    else:
                        self.prestiti[username] = [titolo]
                    self.libri.remove(libro)
                    return "Libro prestato con successo!"
                else:
                    return "Credito insufficiente per prendere in prestito il libro."
            return "Utente non trovato."
        return "Il libro non è disponibile."

    def return_book(self, username, titolo):
        if username in self.prestiti and titolo in self.prestiti[username]:
            self.prestiti[username].remove(titolo)
            if not self.prestiti[username]:
                del self.prestiti[username]
            self.libri.append(Libro(titolo, "Autore sconosciuto", "Anno sconosciuto"))
            return "Libro restituito con successo!"
        return "Il libro non è stato prestato o non esiste."

class Libro:
    def __init__(self, titolo, autore, anno):
        self.titolo = titolo
        self.autore = autore
        self.anno = anno

    def __str__(self):
        return f"{self.titolo} di {self.autore} ({self.anno})"

# Funzioni per la gestione dei menu

def gestione_pre_login(sistema_utenti):
    while True:
        mostra_menu_pre_login()
        scelta_pre_login = int(input("Inserisci scelta: "))

        if scelta_pre_login == 1:
            username = input("Inserisci username: ")
            password = input("Inserisci password: ")
            ruolo = input("Inserisci ruolo (user/admin): ")
            print(sistema_utenti.register(username, password, ruolo))
            sistema_utenti.save_to_file('utenti.json')

        elif scelta_pre_login == 2:
            username = input("Inserisci username: ")
            password = input("Inserisci password: ")
            utente = sistema_utenti.login(username, password)
            if utente:
                if utente.ruolo == 'admin':
                    gestione_menu_admin(sistema_utenti, Libreria())
                else:
                    gestione_menu_utente(utente, Libreria())
            else:
                print("Login fallito. Verifica le tue credenziali.")
        elif scelta_pre_login == 3:
            break

def gestione_menu_utente(utente, libreria):
    while True:
        mostra_menu_utente()
        scelta_utente = int(input("Inserisci scelta: "))

        if scelta_utente == 1:
            print(libreria.list_books())
        elif scelta_utente == 2:
            print(libreria.list_borrowed_books())
        elif scelta_utente == 3:
            titolo = input("Inserisci titolo del libro da prestare: ")
            print(libreria.borrow_book(utente.username, titolo))
        elif scelta_utente == 4:
            titolo = input("Inserisci titolo del libro da restituire: ")
            print(libreria.return_book(utente.username, titolo))
        elif scelta_utente == 5:
            titolo = input("Inserisci titolo del libro da aggiungere: ")
            autore = input("Inserisci autore del libro: ")
            anno = input("Inserisci anno del libro: ")
            libro = Libro(titolo, autore, anno)
            libreria.add_book(libro)
            utente.guadagna_credito(1)
            print("Libro aggiunto con successo e hai guadagnato 1 credito!")
        elif scelta_utente == 6:
            print(f"Saldo crediti: {utente.crediti}")
        elif scelta_utente == 7:
            break

def gestione_menu_admin(sistema_utenti, libreria):
    while True:
        mostra_menu_admin()
        scelta_admin = int(input("Inserisci scelta: "))

        if scelta_admin == 1:
            print(sistema_utenti.list_users())
        elif scelta_admin == 2:
            print(libreria.list_books())
        elif scelta_admin == 3:
            print(libreria.list_borrowed_books())
        elif scelta_admin == 4:
            titolo = input("Inserisci titolo del libro: ")
            autore = input("Inserisci autore del libro: ")
            anno = input("Inserisci anno del libro: ")
            libro = Libro(titolo, autore, anno)
            libreria.add_book(libro)
            print("Libro aggiunto con successo!")
        elif scelta_admin == 5:
            break

def mostra_menu_pre_login():
    print("Menu Pre-Login")
    print("1. Registrati")
    print("2. Login")
    print("3. Esci")

def mostra_menu_utente():
    print("Menu Utente")
    print("1. Visualizza libri")
    print("2. Visualizza libri prestati")
    print("3. Prendi in prestito un libro")
    print("4. Restituisci un libro")
    print("5. Aggiungi un libro")
    print("6. Visualizza saldo crediti")
    print("7. Esci")

def mostra_menu_admin():
    print("Menu Admin")
    print("1. Visualizza utenti")
    print("2. Visualizza libri")
    print("3. Visualizza libri prestati")
    print("4. Aggiungi libro")
    print("5. Esci")

def main():
    sistema_utenti = SistemaGestioneUtenti.load_from_file('utenti.json')
    gestione_pre_login(sistema_utenti)

if __name__ == "__main__":
    main()
