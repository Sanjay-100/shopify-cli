# frozen_string_literal: true
require "shopify_cli"

module ShopifyCLI
  class Command < CLI::Kit::BaseCommand
    autoload :SubCommand,     "shopify_cli/command/sub_command"
    autoload :AppSubCommand,  "shopify_cli/command/app_sub_command"
    autoload :ProjectCommand, "shopify_cli/command/project_command"

    extend Feature::Set

    attr_writer :ctx
    attr_accessor :options

    class << self
      attr_writer :ctx, :task_registry

      def call(args, command_name, *)
        subcommand, resolved_name = subcommand_registry.lookup_command(args.first)
        if subcommand
          subcommand.ctx = @ctx
          subcommand.task_registry = @task_registry

          subcommand.call(args.drop(1), resolved_name, command_name)
        else
          cmd = new(@ctx)
          cmd.options.parse(@_options, args)
          return call_help(command_name) if cmd.options.help
          run_prerequisites
          cmd.call(args, command_name)
        end
      rescue OptionParser::InvalidOption => error
        arg = error.args.first
        store_name = arg.match(/\A--(?<store_name>.*\.myshopify\.com)\z/)&.[](:store_name)
        if store_name && !arg.match?(/\A--(store|shop)=/)
          # Sometimes it may look like --invalidoption=https://storename.myshopify.com
          store_name = store_name.sub(%r{\A(.*=)?(https?://)?}, "")
          raise ShopifyCLI::Abort, @ctx.message("core.errors.option_parser.invalid_option_store_equals", arg, store_name)
        end
        raise ShopifyCLI::Abort, @ctx.message("core.errors.option_parser.invalid_option", arg)
      rescue OptionParser::MissingArgument => error
        arg = error.args.first
        raise ShopifyCLI::Abort, @ctx.message("core.errors.option_parser.missing_argument", arg)
      end

      def options(&block)
        existing_options = @_options
        # We prevent new options calls to override existing blocks by nesting them.
        @_options = ->(parser, flags) {
          existing_options&.call(parser, flags)
          block.call(parser, flags)
        }
      end

      def subcommand(const, cmd, path = nil)
        autoload(const, path) if path
        subcommand_registry.add(->() { const_get(const) }, cmd.to_s)
      end

      def subcommand_registry
        @subcommand_registry ||= CLI::Kit::CommandRegistry.new(
          default: nil,
          contextual_resolver: nil,
        )
      end

      def prerequisite_task(*tasks_without_args, **tasks_with_args)
        @prerequisite_tasks ||= []
        @prerequisite_tasks += tasks_without_args.map { |t| PrerequisiteTask.new(t) }
        @prerequisite_tasks += tasks_with_args.map { |t, args| PrerequisiteTask.new(t, args) }
      end

      def run_prerequisites
        (@prerequisite_tasks || []).each do |task|
          task_registry[task.name]&.call(@ctx, *task.args)
        end
      end

      def task_registry
        @task_registry || ShopifyCLI::Tasks::Registry
      end

      def call_help(*cmds)
        help = Commands::Help.new(@ctx)
        help.call(cmds, nil)
      end

      class PrerequisiteTask
        attr_reader :name, :args

        def initialize(name, args = [])
          @name = name
          @args = args
        end
      end
    end

    def initialize(ctx = nil)
      super()
      @ctx = ctx || ShopifyCLI::Context.new
      self.options = Options.new
    end
  end
end
