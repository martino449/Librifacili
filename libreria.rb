require 'json'
require 'securerandom'

class Libro
  attr_accessor :title, :author, :year, :borrowed_by, :borrowed_on

  def initialize(title, author, year)
    @title = title
    @author = author
    @year = year
    @borrowed_by = nil
    @borrowed_on = nil
  end

  def info
    info_str = "#{@title} by #{@author}, published in #{@year}"
    if @borrowed_by
      info_str += " - Borrowed by #{@borrowed_by.username} on #{@borrowed_on}"
    end
    info_str
  end

  def to_h
    {
      title: @title,
      author: @author,
      year: @year,
      borrowed_by: @borrowed_by&.username,
      borrowed_on: @borrowed_on
    }
  end

  def self.from_h(hash)
    libro = new(hash['title'], hash['author'], hash['year'])
    libro.borrowed_by = hash['borrowed_by'] ? Utente.new(hash['borrowed_by'], '') : nil
    libro.borrowed_on = hash['borrowed_on']
    libro
  end
end

class Libreria
  def initialize
    @libreria = []
  end

  def add_book(libro)
    @libreria << libro
  end

  def list_books
    if @libreria.empty?
      "No books in the library."
    else
      @libreria.map(&:info).join("\n")
    end
  end

  def borrow_book(title, user)
    libro = @libreria.find { |b| b.title.downcase == title.downcase }
    if libro
      if libro.borrowed_by.nil?
        libro.borrowed_by = user
        libro.borrowed_on = Time.now.strftime("%d/%m/%Y")
        "Libro '#{libro.title}' prestato a #{user.username}."
      else
        "Il libro '#{libro.title}' è già preso in prestito da #{libro.borrowed_by.username}."
      end
    else
      "Libro non trovato."
    end
  end

  def return_book(title)
    libro = @libreria.find { |b| b.title.downcase == title.downcase }
    if libro
      if libro.borrowed_by.nil?
        "Il libro '#{libro.title}' non è in prestito."
      else
        libro.borrowed_by = nil
        libro.borrowed_on = nil
        "Libro '#{libro.title}' restituito con successo."
      end
    else
      "Libro non trovato."
    end
  end

  def list_borrowed_books
    borrowed_books = @libreria.select { |b| b.borrowed_by }
    if borrowed_books.empty?
      "Nessun libro attualmente in prestito."
    else
      borrowed_books.map(&:info).join("\n")
    end
  end

  def to_json
    @libreria.map(&:to_h).to_json
  end

  def self.from_json(json_str)
    libreria = new
    libri_data = JSON.parse(json_str)
    libri_data.each do |libro_data|
      libreria.add_book(Libro.from_h(libro_data))
    end
    libreria
  end

  def save_to_file(filename)
    File.write(filename, to_json)
  end

  def self.load_from_file(filename)
    if File.exist?(filename)
      json_str = File.read(filename)
      from_json(json_str)
    else
      new
    end
  end
end

class Utente
  attr_accessor :username, :password

  def initialize(username, password)
    @username = username
    @password = password
  end

  def authenticate(password)
    @password == password
  end

  def to_h
    {
      username: @username,
      password: @password
    }
  end

  def self.from_h(hash)
    new(hash['username'], hash['password'])
  end
end

class SistemaGestioneUtenti
  def initialize
    @utenti = {}
  end

  def register(username, password)
    if @utenti.key?(username)
      "Username già esistente. Scegli un altro username."
    else
      utente = Utente.new(username, password)
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
      "No users registered."
    else
      @utenti.keys.join("\n")
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
    File.write(filename, to_json)
  end

  def self.load_from_file(filename)
    if File.exist?(filename)
      json_str = File.read(filename)
      from_json(json_str)
    else
      new
    end
  end
end

class SistemaGestioneAdmin
  attr_accessor :password

  def initialize(password)
    @password = password
  end

  def authenticate(input_password)
    input_password == @password
  end
end

def mostra_menu_pre_login
  puts "Menu Pre-Login:"
  puts "1. Registrati"
  puts "2. Effettua il login"
  puts "3. Accedi al menu admin (richiesta password)"
  puts "4. Esci"
  print "Scegli un'opzione: "
end

def mostra_menu_admin
  puts "Menu Admin:"
  puts "1. Mostra tutti gli utenti"
  puts "2. Mostra tutti i libri"
  puts "3. Mostra libri in prestito"
  puts "4. Torna al menu principale"
  print "Scegli un'opzione: "
end

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
LIBRI_FILE = 'libreria.json'
UTENTI_FILE = 'utenti.json'

# Carica dati esistenti
libreria = Libreria.load_from_file(LIBRI_FILE)
sistema_utenti = SistemaGestioneUtenti.load_from_file(UTENTI_FILE)
sistema_admin = SistemaGestioneAdmin.new("admin123") # Password di esempio
utente_corrente = nil

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
    puts sistema_utenti.register(username, password)
    sistema_utenti.save_to_file(UTENTI_FILE) # Salva dopo la registrazione

  when 2
    print "Inserisci il tuo username: "
    username = gets.chomp
    print "Inserisci la tua password: "
    password = gets.chomp

    utente = sistema_utenti.login(username, password)
    if utente
      utente_corrente = utente
      puts "Login avvenuto con successo! Benvenuto #{utente.username}.\n\n"
      break
    else
      puts "Username o password non validi. Riprova.\n\n"
    end

  when 3
    print "Inserisci la password admin: "
    password = gets.chomp

    if sistema_admin.authenticate(password)
      loop do
        mostra_menu_admin
        scelta_admin = gets.chomp.to_i

        case scelta_admin
        when 1
          puts "Utenti registrati:"
          puts sistema_utenti.list_users
          puts "\n"

        when 2
          puts "Libri nella libreria:"
          puts libreria.list_books
          puts "\n"

        when 3
          puts "Libri attualmente in prestito:"
          puts libreria.list_borrowed_books
          puts "\n"

        when 4
          break

        else
          puts "Opzione non valida. Riprova.\n\n"
        end
      end
    else
      puts "Password admin non valida. Riprova.\n\n"
    end

  when 4
    puts "Uscita dal programma. Arrivederci!"
    break

  else
    puts "Opzione non valida. Riprova.\n\n"
  end
end

# Menu Post-Login
loop do
  mostra_menu_post_login
  scelta = gets.chomp.to_i

  case scelta
  when 1
    print "Inserisci il titolo del libro: "
    titolo = gets.chomp
    print "Inserisci l'autore del libro: "
    autore = gets.chomp
    print "Inserisci l'anno di pubblicazione: "
    anno = gets.chomp.to_i

    nuovo_libro = Libro.new(titolo, autore, anno)
    libreria.add_book(nuovo_libro)
    libreria.save_to_file(LIBRI_FILE) # Salva dopo l'aggiunta
    puts "Libro aggiunto con successo!\n\n"

  when 2
    puts "Libri nella libreria:"
    puts libreria.list_books
    puts "\n"

  when 3
    print "Inserisci il titolo del libro da prendere in prestito: "
    titolo = gets.chomp
    puts libreria.borrow_book(titolo, utente_corrente)
    libreria.save_to_file(LIBRI_FILE) # Salva dopo il prestito
    puts "\n"

  when 4
    print "Inserisci il titolo del libro da restituire: "
    titolo = gets.chomp
    puts libreria.return_book(titolo)
    libreria.save_to_file(LIBRI_FILE) # Salva dopo la restituzione
    puts "\n"

  when 5
    puts "Libri attualmente in prestito:"
    puts libreria.list_borrowed_books
    puts "\n"

  when 6
    puts "Uscita dal programma. Arrivederci!"
    sistema_utenti.save_to_file(UTENTI_FILE) # Salva gli utenti prima di uscire
    libreria.save_to_file(LIBRI_FILE) # Salva i libri prima di uscire
    break

  else
    puts "Opzione non valida. Riprova.\n\n"
  end
end











#Fine del codice
# ---------------------------------------------
# Copyright (c) 2024 Mario Pisano
#
# Questo programma è distribuito sotto la licenza EUPL, Versione 1.2 o – non appena 
# saranno approvate dalla Commissione Europea – versioni successive della EUPL 
# (la "Licenza");
# Puoi usare, modificare e/o ridistribuire il programma sotto i termini della 
# Licenza. 
# 
# Puoi trovare una copia della Licenza all'indirizzo:
# https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12