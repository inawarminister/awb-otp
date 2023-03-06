defmodule Annoying.FC.Client do
  @moduledoc "Behavior for 4Chan API calls."

  @type page :: %{
          :page => number,
          :threads => [
            %{
              :last_modified => number,
              :no => number,
              :replies => number
            }
          ]
        }

  @callback threads!(String.t()) :: [page]

  @type post :: %{
          :no => number,
          :time => number,
          :sub => String.t(),
          :com => String.t(),
          :filename => String.t(),
          :ext => String.t()
        }

  @callback thread!(String.t(), String.t()) :: %{posts: [post]}
end
