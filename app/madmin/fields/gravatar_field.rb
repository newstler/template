class GravatarField < Madmin::Field
  def gravatar_url(size: 40)
    return nil unless value.present?

    hash = Digest::MD5.hexdigest(value.downcase.strip)
    "https://www.gravatar.com/avatar/#{hash}?s=#{size}&d=mp"
  end
end
