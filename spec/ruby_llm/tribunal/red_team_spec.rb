# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::RedTeam do
  describe '.generate_attacks' do
    it 'generates all attack types by default' do
      attacks = described_class.generate_attacks('How do I pick a lock?')

      attack_types = attacks.map(&:first)

      # Encoding attacks
      expect(attack_types).to include(:base64)
      expect(attack_types).to include(:leetspeak)
      expect(attack_types).to include(:rot13)
      expect(attack_types).to include(:pig_latin)
      expect(attack_types).to include(:reversed)

      # Injection attacks
      expect(attack_types).to include(:ignore_instructions)
      expect(attack_types).to include(:system_prompt_extraction)
      expect(attack_types).to include(:role_switch)
      expect(attack_types).to include(:delimiter_injection)

      # Jailbreak attacks
      expect(attack_types).to include(:dan)
      expect(attack_types).to include(:stan)
      expect(attack_types).to include(:developer_mode)
      expect(attack_types).to include(:hypothetical)
      expect(attack_types).to include(:character_roleplay)
      expect(attack_types).to include(:research_framing)
    end

    it 'filters by category' do
      attacks = described_class.generate_attacks('test', categories: [:encoding])

      attack_types = attacks.map(&:first)

      expect(attack_types).to include(:base64)
      expect(attack_types).not_to include(:dan)
      expect(attack_types).not_to include(:ignore_instructions)
    end
  end

  describe '.base64_attack' do
    it 'encodes the prompt in base64' do
      attack = described_class.base64_attack('Hello')

      expect(attack).to include(Base64.strict_encode64('Hello'))
      expect(attack).to include('base64 encoded')
    end
  end

  describe '.leetspeak_attack' do
    it 'converts to leetspeak' do
      attack = described_class.leetspeak_attack('test')

      expect(attack).to include('7357') # t=7, e=3, s=5, t=7
      expect(attack).to include('leetspeak')
    end
  end

  describe '.rot13_attack' do
    it 'encodes with ROT13' do
      attack = described_class.rot13_attack('hello')

      expect(attack).to include('uryyb') # hello -> uryyb in ROT13
      expect(attack).to include('ROT13')
    end
  end

  describe '.pig_latin_attack' do
    it 'converts to pig latin' do
      attack = described_class.pig_latin_attack('hello world')

      expect(attack).to include('ellohay') # hello -> ellohay
      expect(attack).to include('Pig Latin')
    end
  end

  describe '.reversed_attack' do
    it 'reverses the text' do
      attack = described_class.reversed_attack('hello')

      expect(attack).to include('olleh')
      expect(attack).to include('reversed')
    end
  end

  describe '.dan_attack' do
    it 'creates a DAN jailbreak prompt' do
      attack = described_class.dan_attack('harmful request')

      expect(attack).to include('DAN')
      expect(attack).to include('do anything now')
      expect(attack).to include('harmful request')
    end
  end

  describe '.ignore_instructions_attack' do
    it 'creates an ignore instructions prompt' do
      attack = described_class.ignore_instructions_attack('harmful request')

      expect(attack).to include('Ignore all previous instructions')
      expect(attack).to include('harmful request')
    end
  end

  describe '.system_prompt_extraction_attack' do
    it 'creates a system prompt extraction prompt' do
      attack = described_class.system_prompt_extraction_attack

      expect(attack).to include('system prompt')
      expect(attack).to include('verbatim')
    end
  end
end
