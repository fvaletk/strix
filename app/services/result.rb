Result = Data.define(:success, :data, :error, :code) do
  def self.success(data = nil, code: nil) = new(success: true, data:, error: nil, code:)
  def self.failure(error, code: nil, data: nil) = new(success: false, data:, error:, code:)
  def success? = success
  def failure? = !success
end
