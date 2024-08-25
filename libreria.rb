require 'json'
require 'openssl'
require 'base64'

# Modulo per la crittografia dei dati
class Criptografia
  ALGORITMO = 'aes-256-cbc' # Algoritmo di crittografia simmetrica
  KEY = '12345678901234561234567890123456' # Chiave di crittografia (deve essere lunga 32 byte per aes-256-cbc)
  IV = '1234567890123456' # Vector di inizializzazione (deve essere lungo 16 byte per aes-256-cbc)

  # Metodo per cifrare i dati
  def self.cifra(dati)
    cipher = OpenSSL::Cipher.new(ALGORITMO) # Crea un'istanza del cifratore
    cipher.encrypt # Imposta il cifratore in modalità di cifratura
    cipher.key = KEY # Imposta la chiave di cifratura
    cipher.iv = IV # Imposta il vettore di inizializzazione
    encrypted = cipher.update(dati) + cipher.final # Cifra i dati
    Base64.encode64(encrypted) # Codifica i dati cifrati in Base64 per la memorizzazione
  end

  # Metodo per decifrare i dati
  def self.decifra(dati)
    decipher = OpenSSL::Cipher.new(ALGORITMO) # Crea un'istanza del decifrator
    decipher.decrypt # Imposta il decifrator in modalità di decifratura
    decipher.key = KEY # Imposta la chiave di decifratura
    decipher.iv = IV # Imposta il vettore di inizializzazione
    decoded = Base64.decode64(dati) # Decodifica i dati da Base64
    decipher.update(decoded) + decipher.final # Decifra i dati
  end
end

# Classe che rappresenta un libro
class Libro
  attr_accessor :title, :author, :year, :borrowed_by, :borrowed_on, :crediti

  # Costruttore per inizializzare un libro
  def initialize(title, author, year, crediti)
    @title = title
    @author = author
    @year = year
    @borrowed_by = nil # Inizialmente, il libro non è preso in prestito
    @borrowed_on = nil # Data di prestito non applicabile al momento della creazione
    @crediti = crediti
  end

  # Metodo per ottenere una stringa informativa sul libro
  def info
    info_str = "#{@title} by #{@author}, published in #{@year}, worth #{@crediti} credits"
    if @borrowed_by
      info_str += " - Borrowed by #{@borrowed_by.username} on #{@borrowed_on}"
    end
    info_str
  end

  # Metodo per convertire un libro in un hash
  def to_h
    {
      title: @title,
      author: @author,
      year: @year,
      borrowed_by: @borrowed_by&.username, # Utilizza l'operatore safe navigation per evitare errori se borrowed_by è nil
      borrowed_on: @borrowed_on,
      crediti: @crediti
    }
  end

  # Metodo per creare un libro a partire da un hash
  def self.from_h(hash)
    libro = new(hash['title'], hash['author'], hash['year'], hash['crediti'])
    libro.borrowed_by = hash['borrowed_by'] ? Utente.new(hash['borrowed_by'], '', 0) : nil
    libro.borrowed_on = hash['borrowed_on']
    libro
  end
end

# Classe che rappresenta una libreria
class Libreria
  def initialize
    @libreria = [] # Inizialmente, la libreria è vuota
  end

  # Metodo per aggiungere un libro alla libreria
  def add_book(libro)
    @libreria << libro
  end

  # Metodo per elencare tutti i libri nella libreria
  def list_books
    if @libreria.empty?
      "No books in the library." # Se non ci sono libri, restituisce un messaggio
    else
      @libreria.map(&:info).join("\n") # Converte ogni libro in una stringa e unisce le stringhe
    end
  end

  # Metodo per prendere in prestito un libro
  def borrow_book(title, user)
    libro = @libreria.find { |b| b.title.downcase == title.downcase } # Trova il libro con il titolo specificato
    if libro
      if libro.borrowed_by.nil? # Controlla se il libro non è già in prestito
        if user.crediti >= libro.crediti # Controlla se l'utente ha abbastanza crediti
          libro.borrowed_by = user # Imposta l'utente come colui che ha preso in prestito il libro
          libro.borrowed_on = Time.now.strftime("%d/%m/%Y") # Imposta la data di prestito
          user.crediti -= libro.crediti # Deduce i crediti dell'utente
          "Libro '#{libro.title}' prestato a #{user.username}." # Messaggio di successo
        else
          "Non hai abbastanza crediti per prendere in prestito questo libro." # Messaggio di errore se crediti insufficienti
        end
      else
        "Il libro '#{libro.title}' è già preso in prestito da #{libro.borrowed_by.username}." # Messaggio se il libro è già in prestito
      end
    else
      "Libro non trovato." # Messaggio se il libro non esiste nella libreria
    end
  end

  # Metodo per restituire un libro
  def return_book(title, user)
    libro = @libreria.find { |b| b.title.downcase == title.downcase } # Trova il libro con il titolo specificato
    if libro
      if libro.borrowed_by.nil?
        "Il libro '#{libro.title}' non è in prestito." # Messaggio se il libro non è in prestito
      else
        libro.borrowed_by = nil # Rimuove l'utente che aveva preso in prestito il libro
        libro.borrowed_on = nil # Rimuove la data di prestito
        user.crediti += libro.crediti # Riaggiunge i crediti all'utente
        "Libro '#{libro.title}' restituito con successo. Hai guadagnato #{libro.crediti} crediti." # Messaggio di successo
      end
    else
      "Libro non trovato." # Messaggio se il libro non esiste nella libreria
    end
  end

  # Metodo per elencare tutti i libri in prestito
  def list_borrowed_books
    borrowed_books = @libreria.select { |b| b.borrowed_by } # Seleziona solo i libri che sono in prestito
    if borrowed_books.empty?
      "Nessun libro attualmente in prestito." # Messaggio se nessun libro è in prestito
    else
      borrowed_books.map(&:info).join("\n") # Converte ogni libro in una stringa e unisce le stringhe
    end
  end

  # Metodo per convertire la libreria in una stringa JSON
  def to_json
    @libreria.map(&:to_h).to_json # Converte ogni libro in hash e poi in JSON
  end

  # Metodo per creare una libreria a partire da una stringa JSON
  def self.from_json(json_str)
    libreria = new # Crea una nuova istanza della libreria
    libri_data = JSON.parse(json_str) # Parsea la stringa JSON in un array di hash
    libri_data.each do |libro_data|
      libreria.add_book(Libro.from_h(libro_data)) # Aggiunge ogni libro alla libreria
    end
    libreria
  end

  # Metodo per salvare la libreria su file
  def save_to_file(filename)
    dati = to_json # Converte la libreria in JSON
    encrypted_dati = Criptografia.cifra(dati) # Cifra i dati
    File.write(filename, encrypted_dati) # Scrive i dati cifrati su file
  end

  # Metodo per caricare la libreria da un file
  def self.load_from_file(filename)
    if File.exist?(filename) # Controlla se il file esiste
      encrypted_dati = File.read(filename) # Legge i dati cifrati dal file
      dati = Criptografia.decifra(encrypted_dati) # Decifra i dati
      from_json(dati) # Crea una libreria a partire dai dati JSON decifrati
    else
      new # Restituisce una nuova libreria se il file non esiste
    end
  end
end

# Classe che rappresenta un utente
class Utente
  attr_accessor :username, :password, :crediti

  # Costruttore per inizializzare un utente
  def initialize(username, password, crediti = 0)
    @username = username
    @password = password
    @crediti = crediti
  end

  # Metodo per autenticare l'utente
  def authenticate(password)
    @password == password # Controlla se la password fornita corrisponde a quella dell'utente
  end

  # Metodo per convertire un utente in un hash
  def to_h
    {
      username: @username,
      password: @password,
      crediti: @crediti
    }
  end

  # Metodo per creare un utente a partire da un hash
  def self.from_h(hash)
    new(hash['username'], hash['password'], hash['crediti'])
  end
end

# Classe per gestire il sistema degli utenti
class SistemaGestioneUtenti
  def initialize
    @utenti = {} # Hash per memorizzare gli utenti
  end

  # Metodo per registrare un nuovo utente
  def register(username, password)
    if @utenti.key?(username) # Controlla se l'username è già esistente
      "Username già esistente. Scegli un altro username." # Messaggio di errore se l'username è già in uso
    else
      utente = Utente.new(username, password) # Crea un nuovo utente
      @utenti[username] = utente # Aggiunge l'utente al sistema
      "Registrazione avvenuta con successo! Puoi ora effettuare il login." # Messaggio di successo
    end
  end

  # Metodo per effettuare il login
  def login(username, password)
    utente = @utenti[username] # Trova l'utente con lo username fornito
    utente && utente.authenticate(password) ? utente : nil # Restituisce l'utente se autenticato, altrimenti nil
  end

  # Metodo per elencare tutti gli utenti
  def list_users
    if @utenti.empty?
      "No users registered." # Messaggio se non ci sono utenti registrati
    else
      @utenti.map { |username, utente| "#{username} - Crediti: #{utente.crediti}" }.join("\n") # Elenco degli utenti e dei loro crediti
    end
  end

  # Metodo per convertire il sistema di gestione utenti in JSON
  def to_json
    @utenti.values.map(&:to_h).to_json # Converte ogni utente in hash e poi in JSON
  end

  # Metodo per creare un sistema di gestione utenti a partire da una stringa JSON
  def self.from_json(json_str)
    sistema = new # Crea una nuova istanza del sistema di gestione utenti
    utenti_data = JSON.parse(json_str) # Parsea la stringa JSON in un array di hash
    utenti_data.each do |utente_data|
      sistema.add_user(Utente.from_h(utente_data)) # Aggiunge ogni utente al sistema
    end
    sistema
  end

  # Metodo per aggiungere un utente al sistema
  def add_user(utente)
    @utenti[utente.username] = utente # Aggiunge l'utente al sistema
  end

  # Metodo per salvare il sistema di gestione utenti su file
  def save_to_file(filename)
    dati = to_json # Converte il sistema in JSON
    encrypted_dati = Criptografia.cifra(dati) # Cifra i dati
    File.write(filename, encrypted_dati) # Scrive i dati cifrati su file
  end

  # Metodo per caricare il sistema di gestione utenti da un file
  def self.load_from_file(filename)
    if File.exist?(filename) # Controlla se il file esiste
      encrypted_dati = File.read(filename) # Legge i dati cifrati dal file
      dati = Criptografia.decifra(encrypted_dati) # Decifra i dati
      from_json(dati) # Crea un sistema a partire dai dati JSON decifrati
    else
      new # Restituisce un nuovo sistema se il file non esiste
    end
  end
end

# Classe per gestire le operazioni dell'admin
class SistemaGestioneAdmin
  attr_accessor :password

  # Costruttore per inizializzare il sistema di gestione admin
  def initialize(password)
    @password = password # Imposta la password dell'admin
  end

  # Metodo per autenticare l'admin
  def authenticate(input_password)
    input_password == @password # Controlla se la password fornita corrisponde a quella dell'admin
  end
end

# Metodo per mostrare il menu pre-login
def mostra_menu_pre_login
  puts "Menu Pre-Login:"
  puts "1. Registrati"
  puts "2. Effettua il login"
  puts "3. Accedi al menu admin (richiesta password)"
  puts "4. Esci"
  print "Scegli un'opzione: "
end

# Metodo per mostrare il menu admin
def mostra_menu_admin
  puts "Menu Admin:"
  puts "1. Mostra tutti gli utenti"
  puts "2. Mostra tutti i libri"
  puts "3. Mostra libri in prestito"
  puts "4. Torna al menu principale"
  print "Scegli un'opzione: "
end

# Metodo per mostrare il menu post-login
def mostra_menu_post_login
  puts "Menu Post-Login:"
  puts "1. Aggiungi un nuovo libro"
  puts "2. Mostra tutti i libri"
  puts "3. Prendi in prestito un libro"
  puts "4. Restituisci un libro"
  puts "5. Mostra libri in prestito"
  puts "6. Esci"
  print "Scegli un'opzione: "
end

# File di salvataggio
LIBRI_FILE = 'libreria.json' # File per salvare la libreria
UTENTI_FILE = 'utenti.json' # File per salvare gli utenti

# Carica i dati esistenti
libreria = Libreria.load_from_file(LIBRI_FILE) # Carica i libri dal file
sistema_utenti = SistemaGestioneUtenti.load_from_file(UTENTI_FILE) # Carica gli utenti dal file
sistema_admin = SistemaGestioneAdmin.new("admin123") # Crea un'istanza del sistema admin con una password di esempio
utente_corrente = nil # Variabile per memorizzare l'utente attualmente loggato

# Menu Pre-Login
loop do
  mostra_menu_pre_login
  scelta = gets.chomp.to_i

  case scelta
  when 1
    print "Inserisci un username: "
    username = gets.chomp
    print "Inserisci una password: "
    password = gets.chomp
    puts sistema_utenti.register(username, password) # Registra l'utente e mostra il risultato
    sistema_utenti.save_to_file(UTENTI_FILE) # Salva i dati degli utenti

  when 2
    print "Inserisci il tuo username: "
    username = gets.chomp
    print "Inserisci la tua password: "
    password = gets.chomp

    utente = sistema_utenti.login(username, password) # Prova a fare il login
    if utente
      utente_corrente = utente # Imposta l'utente corrente se il login ha successo
      puts "Login avvenuto con successo! Benvenuto #{utente.username}.\n\n"
      break # Esce dal loop pre-login se il login è avvenuto con successo
    else
      puts "Username o password non validi. Riprova.\n\n" # Messaggio di errore per credenziali non valide
    end

  when 3
    print "Inserisci la password admin: "
    password = gets.chomp

    if sistema_admin.authenticate(password) # Prova ad autenticare l'admin
      loop do
        mostra_menu_admin
        scelta_admin = gets.chomp.to_i

        case scelta_admin
        when 1
          puts "Utenti registrati:"
          puts sistema_utenti.list_users # Mostra tutti gli utenti
          puts "\n"

        when 2
          puts "Libri nella libreria:"
          puts libreria.list_books # Mostra tutti i libri
          puts "\n"

        when 3
          puts "Libri in prestito:"
          puts libreria.list_borrowed_books # Mostra tutti i libri in prestito
          puts "\n"

        when 4
          puts "Ritorno al menu principale...\n\n"
          break # Esce dal menu admin e torna al menu principale
        else
          puts "Opzione non valida, riprova." # Messaggio di errore per opzione non valida
        end
      end
    else
      puts "Password admin non valida." # Messaggio di errore per password admin non valida
    end

  when 4
    puts "Arrivederci!"
    exit # Termina l'applicazione

  else
    puts "Opzione non valida. Riprova.\n\n" # Messaggio di errore per opzione non valida
  end
end

# Menu Post-Login
loop do
  mostra_menu_post_login
  scelta = gets.chomp.to_i

  case scelta
  when 1
    print "Inserisci il titolo del libro: "
    title = gets.chomp
    print "Inserisci l'autore del libro: "
    author = gets.chomp
    print "Inserisci l'anno di pubblicazione: "
    year = gets.chomp
    print "Inserisci i crediti per questo libro (1-5): "
    crediti = gets.chomp.to_i

    if crediti < 1 || crediti > 5
      puts "I crediti devono essere tra 1 e 5. Riprova." # Messaggio di errore per crediti non validi
    else
      libro = Libro.new(title, author, year, crediti) # Crea un nuovo libro
      libreria.add_book(libro) # Aggiunge il libro alla libreria
      utente_corrente.crediti += 1 # Guadagna 1 credito per aggiungere un libro
      libreria.save_to_file(LIBRI_FILE) # Salva i dati della libreria
      sistema_utenti.save_to_file(UTENTI_FILE) # Salva i dati degli utenti
      puts "Libro aggiunto con successo! Hai guadagnato 1 credito." # Messaggio di successo
    end

  when 2
    puts "Libri nella libreria:"
    puts libreria.list_books # Mostra tutti i libri nella libreria
    puts "\n"

  when 3
    print "Inserisci il titolo del libro che vuoi prendere in prestito: "
    title = gets.chomp
    puts libreria.borrow_book(title, utente_corrente) # Prova a prendere in prestito un libro
    libreria.save_to_file(LIBRI_FILE) # Salva i dati della libreria
    sistema_utenti.save_to_file(UTENTI_FILE) # Salva i dati degli utenti

  when 4
    print "Inserisci il titolo del libro che vuoi restituire: "
    title = gets.chomp
    puts libreria.return_book(title, utente_corrente) # Prova a restituire un libro
    libreria.save_to_file(LIBRI_FILE) # Salva i dati della libreria
    sistema_utenti.save_to_file(UTENTI_FILE) # Salva i dati degli utenti

  when 5
    puts "Libri in prestito:"
    puts libreria.list_borrowed_books # Mostra tutti i libri in prestito
    puts "\n"

  when 6
    puts "Arrivederci!"
    exit # Termina l'applicazione

  else
    puts "Opzione non valida. Riprova." # Messaggio di errore per opzione non valida
  end
end
