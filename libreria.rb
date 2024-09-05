require 'json'
require 'openssl'
require 'base64'

# Modulo per la crittografia dei dati
module Criptografia
  ALGORITMO = 'aes-256-cbc'
  KEY = '12345678901234561234567890123456'
  IV = '1234567890123456'

  def self.cifra(dati)
    cipher = OpenSSL::Cipher.new(ALGORITMO)
    cipher.encrypt
    cipher.key = KEY
    cipher.iv = IV
    encrypted = cipher.update(dati) + cipher.final
    Base64.encode64(encrypted)
  end

  def self.decifra(dati)
    decipher = OpenSSL::Cipher.new(ALGORITMO)
    decipher.decrypt
    decipher.key = KEY
    decipher.iv = IV
    decoded = Base64.decode64(dati)
    decipher.update(decoded) + decipher.final
  end
end

# Classe che rappresenta un utente
class Utente
  attr_accessor :username, :password, :crediti, :ruolo

  def initialize(username, password, crediti = 0, ruolo = 'user')
    @username = username
    @password = password
    @crediti = crediti
    @ruolo = ruolo
  end

  def authenticate(password)
    @password == password
  end

  def guadagna_credito(amount)
    @crediti += amount
  end

  def spende_credito(amount)
    if @crediti >= amount
      @crediti -= amount
      true
    else
      false
    end
  end

  def to_h
    {
      username: @username,
      password: @password,
      crediti: @crediti,
      ruolo: @ruolo
    }
  end

  def self.from_h(hash)
    new(hash['username'], hash['password'], hash['crediti'], hash['ruolo'])
  end
end

# Classe per gestire il sistema degli utenti
class SistemaGestioneUtenti
  def initialize
    @utenti = {}
  end

  def register(username, password, ruolo = 'user')
    if @utenti.key?(username)
      "Username già esistente. Scegli un altro username."
    else
      utente = Utente.new(username, password, 0, ruolo)
      @utenti[username] = utente
      "Registrazione avvenuta con successo! Puoi ora effettuare il login."
    end
  end

  def login(username, password)
    utente = @utenti[username]
    utente && utente.authenticate(password) ? utente : nil
  end

  def list_users
    if @utenti.empty?
      "Nessun utente registrato."
    else
      @utenti.map { |username, utente| "#{username} - Crediti: #{utente.crediti}" }.join("\n")
    end
  end

  def to_json
    @utenti.values.map(&:to_h).to_json
  end

  def self.from_json(json_str)
    sistema = new
    utenti_data = JSON.parse(json_str)
    utenti_data.each do |utente_data|
      sistema.add_user(Utente.from_h(utente_data))
    end
    sistema
  end

  def add_user(utente)
    @utenti[utente.username] = utente
  end

  def save_to_file(filename)
    dati = to_json
    encrypted_dati = Criptografia.cifra(dati)
    File.write(filename, encrypted_dati)
  end

  def self.load_from_file(filename)
    if File.exist?(filename)
      encrypted_dati = File.read(filename)
      dati = Criptografia.decifra(encrypted_dati)
      from_json(dati)
    else
      new
    end
  end
end

# Classe per gestire la libreria
class Libreria
  def initialize
    @libri = []
    @prestiti = {}
  end

  def add_book(book)
    @libri << book
  end

  def list_books
    if @libri.empty?
      "Nessun libro disponibile."
    else
      @libri.map(&:to_s).join("\n")
    end
  end

  def list_borrowed_books
    if @prestiti.empty?
      "Nessun libro è stato prestato."
    else
      @prestiti.map { |username, libri| "#{username}: #{libri.join(', ')}" }.join("\n")
    end
  end

  def borrow_book(username, titolo)
    libro = @libri.find { |l| l.titolo == titolo }
    if libro
      utente = SistemaGestioneUtenti.load_from_file('utenti.json').login(username, '')
      if utente
        if utente.spende_credito(1)
          if @prestiti[username]
            @prestiti[username] << titolo
          else
            @prestiti[username] = [titolo]
          end
          @libri.delete(libro)
          "Libro prestato con successo!"
        else
          "Credito insufficiente per prendere in prestito il libro."
        end
      else
        "Utente non trovato."
      end
    else
      "Il libro non è disponibile."
    end
  end

  def return_book(username, titolo)
    if @prestiti[username] && @prestiti[username].include?(titolo)
      libro = Libro.new(titolo, "Autore sconosciuto", "Anno sconosciuto") # Aggiungere autore e anno appropriati
      @libri << libro
      @prestiti[username].delete(titolo)
      @prestiti.delete(username) if @prestiti[username].empty?

      # Guadagnare credito quando restituisce il libro
      utente = SistemaGestioneUtenti.load_from_file('utenti.json').login(username, '')
      if utente
        utente.guadagna_credito(1)
      end

      "Libro restituito con successo!"
    else
      "Il libro non è stato prestato o non esiste."
    end
  end

  def to_json
    {
      libri: @libri.map(&:to_h),
      prestiti: @prestiti
    }.to_json
  end

  def self.from_json(json_str)
    data = JSON.parse(json_str)
    libreria = new
    data['libri'].each do |libro_data|
      libreria.add_book(Libro.from_h(libro_data))
    end
    libreria.instance_variable_set(:@prestiti, data['prestiti'])
    libreria
  end

  def save_to_file(filename)
    dati = to_json
    encrypted_dati = Criptografia.cifra(dati)
    File.write(filename, encrypted_dati)
  end

  def self.load_from_file(filename)
    if File.exist?(filename)
      encrypted_dati = File.read(filename)
      dati = Criptografia.decifra(encrypted_dati)
      from_json(dati)
    else
      new
    end
  end
end

# Classe per rappresentare un libro
class Libro
  attr_accessor :titolo, :autore, :anno

  def initialize(titolo, autore, anno)
    @titolo = titolo
    @autore = autore
    @anno = anno
  end

  def to_h
    {
      titolo: @titolo,
      autore: @autore,
      anno: @anno
    }
  end

  def self.from_h(hash)
    new(hash['titolo'], hash['autore'], hash['anno'])
  end

  def to_s
    "#{@titolo} di #{@autore} (#{@anno})"
  end
end

# Classe per la gestione delle operazioni da amministratore
class SistemaGestioneAdmin
  def initialize(password)
    @admin_password = password
  end

  def authenticate(password)
    @admin_password == password
  end
end

# File di configurazione
LIBRERIA_FILE = 'libreria.json'
UTENTI_FILE = 'utenti.json'
ADMIN_PASSWORD = 'admin123'
CREDITO_AGGIUNTA_LIBRO = 1 # Credito guadagnato per ogni libro aggiunto

# Inizializzazione
libreria = Libreria.load_from_file(LIBRERIA_FILE)
sistema_utenti = SistemaGestioneUtenti.load_from_file(UTENTI_FILE)

# Creazione dell'utente admin se non esiste
unless sistema_utenti.login('admin', ADMIN_PASSWORD)
  sistema_utenti.register('admin', ADMIN_PASSWORD, 'admin')
  sistema_utenti.save_to_file(UTENTI_FILE)
end

admin_sistema = SistemaGestioneAdmin.new(ADMIN_PASSWORD)

# Funzioni di visualizzazione del menu
def mostra_menu_pre_login
  puts "Menu Pre-Login"
  puts "1. Registrazione"
  puts "2. Login"
  puts "3. Uscita"
end

def mostra_menu_utente
  puts "Menu Utente"
  puts "1. Visualizza Libri"
  puts "2. Visualizza Libri Prestati"
  puts "3. Prestare Libro"
  puts "4. Restituire Libro"
  puts "5. Aggiungere Libro e Guadagnare Credito"
  puts "6. Visualizza Saldo Crediti"
  puts "7. Esci"
end

def mostra_menu_admin
  puts "Menu Admin"
  puts "1. Lista Utenti"
  puts "2. Visualizza Libri"
  puts "3. Visualizza Libri Prestati"
  puts "4. Aggiungi Libro"
  puts "5. Esci"
end

# Main Program
loop do
  mostra_menu_pre_login
  scelta_pre_login = gets.chomp.to_i

  case scelta_pre_login
  when 1
    print "Inserisci username: "
    username = gets.chomp
    print "Inserisci password: "
    password = gets.chomp
    print "Inserisci ruolo (user/admin): "
    ruolo = gets.chomp
    puts sistema_utenti.register(username, password, ruolo)
    sistema_utenti.save_to_file(UTENTI_FILE)
  when 2
    print "Inserisci username: "
    username = gets.chomp
    print "Inserisci password: "
    password = gets.chomp
    utente = sistema_utenti.login(username, password)

    if utente
      if utente.ruolo == 'admin'
        puts "Benvenuto admin!"
        loop do
          mostra_menu_admin
          scelta_admin = gets.chomp.to_i

          case scelta_admin
          when 1
            puts sistema_utenti.list_users
          when 2
            puts libreria.list_books
          when 3
            puts libreria.list_borrowed_books
          when 4
            print "Inserisci titolo del libro: "
            titolo = gets.chomp
            print "Inserisci autore del libro: "
            autore = gets.chomp
            print "Inserisci anno del libro: "
            anno = gets.chomp.to_i
            libro = Libro.new(titolo, autore, anno)
            libreria.add_book(libro)
            libreria.save_to_file(LIBRERIA_FILE)
            puts "Libro aggiunto con successo!"
          when 5
            break
          else
            puts "Scelta non valida."
          end
        end
      else
        puts "Benvenuto #{utente.username}!"
        loop do
          mostra_menu_utente
          scelta_utente = gets.chomp.to_i

          case scelta_utente
          when 1
            puts libreria.list_books
          when 2
            puts libreria.list_borrowed_books
          when 3
            print "Inserisci titolo del libro da prestare: "
            titolo = gets.chomp
            if utente.spende_credito(1)
              puts libreria.borrow_book(utente.username, titolo)
              libreria.save_to_file(LIBRERIA_FILE)
              sistema_utenti.save_to_file(UTENTI_FILE)
            else
              puts "Credito insufficiente per prendere in prestito il libro."
            end
          when 4
            print "Inserisci titolo del libro da restituire: "
            titolo = gets.chomp
            puts libreria.return_book(utente.username, titolo)
            utente.guadagna_credito(CREDITO_AGGIUNTA_LIBRO)
            libreria.save_to_file(LIBRERIA_FILE)
            sistema_utenti.save_to_file(UTENTI_FILE)
          when 5
            print "Inserisci titolo del libro da aggiungere: "
            titolo = gets.chomp
            print "Inserisci autore del libro: "
            autore = gets.chomp
            print "Inserisci anno del libro: "
            anno = gets.chomp.to_i
            libro = Libro.new(titolo, autore, anno)
            libreria.add_book(libro)
            utente.guadagna_credito(CREDITO_AGGIUNTA_LIBRO)
            libreria.save_to_file(LIBRERIA_FILE)
            sistema_utenti.save_to_file(UTENTI_FILE)
            puts "Libro aggiunto e credito guadagnato con successo!"
          when 6
            puts "Saldo crediti: #{utente.crediti}"
          when 7
            break
          else
            puts "Scelta non valida."
          end
        end
      end
    else
      puts "Username o password errati."
    end
  when 3
    puts "Uscita dal programma."
    break
  else
    puts "Scelta non valida."
  end
end
