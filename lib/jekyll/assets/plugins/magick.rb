# Frozen-string-literal: true
# Copyright: 2012 - 2017 - MIT License
# Encoding: utf-8

module Jekyll
  module Assets
    module Proxies
      class MiniMagick
        ARGS = %W(resize quality rotate crop flip format gravity strip).freeze
        PRESETS = %W(@2x @4x @1/2 @1/3 @2/3 @1/4 @2/4 @3/4
          @double @quadruple @half @one-third @two-thirds @one-fourth
            @two-fourths @three-fourths).freeze

        # --
        class DoubleResizeError < RuntimeError
          def initialize
            "Both resize and @*x provided, this is not supported."
          end
        end

        # --
        # @see https://github.com/minimagick/minimagick#usage -- All but
        #   the boolean @ options are provided by Minimagick.
        # --
        def initialize(asset, opts, args)
          @asset = asset
          @opts = opts
          @args = args
        end

        # --
        def process
          img = MiniMagick::Image.open(@asset.filename)
          methods = private_methods(true).select { |v| v.to_s.start_with?("magick_") }
          if img.respond_to?(:combine_options)
            then img.combine_options do |c|
              methods.each do |m|
                send(m, img, c)
              end
            end

          else
            methods.each do |m|
              send(m, img, img)
            end
          end

          img.write(@asset.filename)
        ensure
          img.destroy!
        end

        # --
        private
        def any_preset?(*keys)
          @opts.keys.any? do |key|
            keys.include?(key)
          end
        end

        # --
        private
        def preset?
          (@opts.keys - ARGS.map(&:to_sym)).any?
        end

        # --
        private
        def magick_quality(_, cmd)
          if @opts.key?(:quality)
            then cmd.quality @opts[:quality]
          end
        end

        # --
        private
        def magick_resize(_, cmd)
          raise DoubleResizeError if @opts.key?(:resize) && preset?
          if @opts.key?(:resize)
            then cmd.resize @opts[:resize]
          end
        end

        # --
        private
        def magick_rotate(_, cmd)
          if @opts.key?(:rotate)
            then cmd.rotate @opts[:rotate]
          end
        end

        # --
        private
        def magick_flip(_, cmd)
          if @opts.key?(:flip)
            then cmd.flip @opts[:flip]
          end
        end

        # --
        private
        def magick_format(img, _)
          if @opts.key?(:format)
            img.format @opts[:format]
            @asset.content_type = img.mime_type
          end
        end

        # --
        private
        def magick_crop(_, cmd)
          if @opts.key?(:crop)
            then cmd.crop @opts[:crop]
          end
        end

        # --
        private
        def magick_gravity(_, cmd)
          if @opts.key?(:gravity)
            then cmd.gravity @opts[:gravity]
          end
        end

        # --
        private
        def magick_strip(_, cmd)
          cmd.strip
        end

        # --
        # I just want you to know, we don't even care if you do multiple
        # resizes or try to, we don't attempt to even attempt to attempt to care
        # we expect you to be logical and if you aren't we will comply.
        # --
        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Style/ParallelAssignment
        # rubocop:disable Metrics/AbcSize
        # --

        private
        def magick_preset_resize(img, cmd)
          return unless preset?
          width, height = img.width * 4, img.height * 4 if any_preset?(:"4x", :quadruple)
          width, height = img.width * 2, img.height * 2 if any_preset?(:"2x", :double)
          width, height = img.width / 2, img.height / 2 if any_preset?(:"1/2", :half)
          width, height = img.width / 3, img.height / 3 if any_preset?(:"1/3", :"one-third")
          width, height = img.width / 4, img.height / 4 if any_preset?(:"1/4", :"one-fourth")
          width, height = img.width / 3 * 2, img.height / 3 * 2 if any_preset?(:"2/3", :"two-thirds")
          width, height = img.width / 4 * 2, img.height / 4 * 2 if any_preset?(:"2/4", :"two-fourths")
          width, height = img.width / 4 * 3, img.height / 4 * 3 if any_preset?(:"3/4", :"three-fourths")
          cmd.resize "#{width}x#{height}"
        end

        # --
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Style/ParallelAssignment
        # rubocop:enable Metrics/AbcSize
        # --
      end
    end
  end
end

try_require "mini_magick" do
  klass = Jekyll::Assets::Proxies::MiniMagick
  args = klass::PRESETS + klass::ARGS
  reg = [
    :img, :asset_path
  ]

  Jekyll::Assets::Liquid::Tag::Proxies.add :magick, reg, *args do
    def initialize(asset, opts, args)
      @magick = klass.new(asset, opts, args)
    end

    # --
    def process
      @magick.process
    end
  end
end
