module StellarCoreCommander

  class OperationBuilder
    include Contracts

    Currency = [String, Symbol]
    Amount = Any #TODO

    OfferCurrencies = Or[
      {sell:Currency, for: Currency},
      {buy:Currency, with: Currency},
    ]

    Contract Transactor => Any
    def initialize(transactor)
      @transactor = transactor
    end

    Contract Symbol, Symbol, Amount, Or[{}, {path: Any}] => Any
    def payment(from, to, amount, options={})
      from = get_account from
      to   = get_account to

      if amount.first != :native
        amount    = [:iso4217] + amount
        amount[2] = get_account(amount[2])
        amount[1] = amount[1].ljust(4, "\x00")
      end

      attrs = {
        account:     from,
        destination: to,
        sequence:    next_sequence(from),
        amount:      amount,
      }

      if options[:path]
        attrs[:path] = options[:path].map{|p| make_currency p}
      end

      Stellar::Transaction.payment(attrs).to_envelope(from)
    end

    Contract Symbol, Symbol, String => Any
    def trust(account, issuer, code)
      change_trust account, issuer, code, (2**63)-1
    end    

    Contract Symbol, Symbol, String, Num => Any
    def change_trust(account, issuer, code, limit)
      account = get_account account

      Stellar::Transaction.change_trust({
        account:  account,
        sequence: next_sequence(account),
        line:     make_currency([code, issuer]),
        limit:    limit
      }).to_envelope(account)
    end  

    Contract Symbol, Symbol, String, Num => Any
    def allow_trust(account, trustor, code)
      account = get_account account
      trustor = get_account trustor

      Stellar::Transaction.allow_trust({
        account:  account,
        sequence: next_sequence(account),
        currency: make_currency([code, account]),
        trustor:  trustor
      }).to_envelope(account)
    end

    Contract Symbol, OfferCurrencies, Num, Num => Any
    def offer(account, currencies, amount, price)
      account = get_account account

      if currencies.has_key?(:sell)
        taker_pays = make_currency currencies[:for]
        taker_gets = make_currency currencies[:sell]
      else
        taker_pays = make_currency currencies[:buy]
        taker_gets = make_currency currencies[:with]
      end

      Stellar::Transaction.create_offer({
        account:  account,
        sequence: next_sequence(account),
        taker_gets: taker_gets,
        taker_pays: taker_pays,
        amount: amount,
        price: price,
      }).to_envelope(account)      
    end


    private

    delegate :get_account, to: :@transactor
    delegate :next_sequence, to: :@transactor

    Contract Currency => [Symbol, String, Stellar::KeyPair]
    def make_currency(input)
      code, issuer = *input
      code = code.ljust(4, "\x00")
      issuer = get_account issuer

      [:iso4217, code, issuer]
    end

    def make_account_flags(flags=nil)
      flags ||= []
      flags = flags.map{|f| Stellar::AccountFlags.send(f)}
      Stellar::AccountFlags.make_mask flags
    end

  end
end