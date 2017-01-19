local matrix = require("matrix")
local log = require("log")

local learningAlgorithms = {}

function learningAlgorithms.linearRegression (X, y)
	--beta = (X.T * X).-1 * X.T * y	
	local XtotheT = matrix.transpose( X )
	local Xtothe2 = matrix.mul( XtotheT, X )
	if matrix.det( Xtothe2 ) == 0 then return nil end
	local partOne = matrix.invert( Xtothe2 )
	local partOneAndTwo = matrix.mul( partOne, XtotheT )
	local betaHat = matrix.mul( partOneAndTwo, y )
	return betaHat
end

return learningAlgorithms