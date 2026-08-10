class PacientePolicy < ApplicationPolicy
  # ── Allowlists explícitas por ROL ─────────────────────────────────────────────
  # Quién puede VER la ficha (datos NO clínicos). El dispensador entra para dispensar.
  # El super admin entra SÓLO mientras observa un club (ver `observando?`): es lo que hace que
  # "ver el club como lo ve su admin" incluya la ficha operativa del paciente. La historia
  # clínica sigue afuera — ROLES_CLINICA no lo incluye — y eso es a propósito.
  ROLES_LECTURA        = %w[admin medico supervisor dispensador].freeze
  # Quién puede VER datos clínicos / historia clínica. Decisión POR ROL (allowlist),
  # NO por presencia/ausencia de club: super_admin y dispensador quedan FUERA a propósito
  # (super_admin es rol de plataforma; el dispensador no accede a datos de salud).
  ROLES_CLINICA        = %w[admin medico supervisor].freeze
  # Quién puede EDITAR datos clínicos (más restrictivo que verlos).
  ROLES_EDITAR_CLINICA = %w[admin medico].freeze

  class Scope < ApplicationPolicy::Scope
    def resolve
      base = scope.for_club(user.club_id)
      if user.medico?
        base.where(es_paciente: true, con_seguimiento_medico: true)
      elsif user.dispensador?
        base.where(es_paciente: true)
      else
        base
      end
    end
  end

  def index?
    mismo_club? && puede_leer_ficha?
  end

  def show?
    mismo_club? && puede_leer_ficha?
  end

  def create?
    mismo_club? && (admin? || medico? || user&.dispensador?)
  end

  def update?
    mismo_club? && ROLES_EDITAR_CLINICA.include?(user&.role)
  end

  def destroy?
    mismo_club? && admin?
  end

  # ── Datos clínicos ────────────────────────────────────────────────────────────
  # Ver historia clínica: allowlist explícita medico/admin/supervisor. super_admin y
  # dispensador NO están en ROLES_CLINICA → bloqueados por ROL, no por falta de club.
  def ver_notas_clinicas?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  # Editar datos clínicos: sólo admin/medico.
  def update_notas_clinicas?
    mismo_club? && ROLES_EDITAR_CLINICA.include?(user&.role)
  end

  # El timeline incluye eventos clínicos (indicaciones, turnos con motivo) → mismo
  # criterio que ver la historia clínica.
  def timeline?
    mismo_club? && ROLES_CLINICA.include?(user&.role)
  end

  private

  # Aislamiento multi-tenant (defensa en profundidad). NO es la decisión de acceso
  # clínico — esa la toma la allowlist de rol de arriba —, sino la barrera de club:
  # un usuario de un club nunca ve datos de otro club.
  def mismo_club?
    user.present? && user.club_id.present? && record.club_id == user.club_id
  end

  # El super admin sólo lee fichas mientras OBSERVA un club, nunca por ser super admin: fuera
  # del modo observador no tiene club, así que `mismo_club?` ya lo dejaría afuera — esto lo
  # hace explícito en vez de depender de ese efecto lateral.
  def puede_leer_ficha?
    return user.modo_observador? if user&.super_admin?

    ROLES_LECTURA.include?(user&.role)
  end
end
