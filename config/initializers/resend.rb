# frozen_string_literal: true

# Resend HTTP API (see ResendApiSender, MailDeliveryResendFallback).
::OutboundMailConfig.configure_resend_client!
