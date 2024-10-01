#pragma once

#include <DataTypes/DataTypeString.h>
#include <Columns/ColumnString.h>
#include <Columns/ColumnFixedString.h>
#include <Functions/FunctionHelpers.h>
#include <Functions/IFunction.h>
#include <Interpreters/Context_fwd.h>


namespace DB
{

namespace ErrorCodes
{
    extern const int ILLEGAL_COLUMN;
    extern const int ILLEGAL_TYPE_OF_ARGUMENT;
}


template <typename Impl, typename Name, bool is_injective = false>
class FunctionStringToString : public IFunction
{
public:
    static constexpr auto name = Name::name;
    static FunctionPtr create(ContextPtr)
    {
        return std::make_shared<FunctionStringToString>();
    }

    String getName() const override
    {
        return name;
    }

    size_t getNumberOfArguments() const override
    {
        return 1;
    }

    // Seemed like including this would allow for more than one arg. Wouldn't restrict it to 2 tho
    // Not sure if that's a problem
    // bool isVariadic() const override
    // {
    //     if (has_mode<Impl>::value && std::is_same_v<Impl, DB::FunctionTrimImpl<typename Impl::Mode>>)
    //         return true;
    //     else
    //         return false;
    // }

    bool isInjective(const ColumnsWithTypeAndName &) const override
    {
        return is_injective;
    }

    bool isSuitableForShortCircuitArgumentsExecution(const DataTypesWithConstInfo & /*arguments*/) const override
    {
        return true;
    }

    DataTypePtr getReturnTypeImpl(const DataTypes & arguments) const override
    {
        if (!isStringOrFixedString(arguments[0]))
            throw Exception(ErrorCodes::ILLEGAL_TYPE_OF_ARGUMENT, "Illegal type {} of argument of function {}",
                arguments[0]->getName(), getName());

        return arguments[0];
    }

    bool useDefaultImplementationForConstants() const override { return true; }

    ColumnPtr executeImpl(const ColumnsWithTypeAndName & arguments, const DataTypePtr &, size_t input_rows_count) const override
    {
        const ColumnPtr column = arguments[0].column;
        if (const ColumnString * col = checkAndGetColumn<ColumnString>(column.get()))
        {
            auto col_res = ColumnString::create();
            // // COMPILE ERROR: find a way for this logic
            // if constexpr (has_mode<Impl>::value && std::is_same_v<Impl, DB::FunctionTrimImpl<typename Impl::Mode>>) {
            //     char pattern = ' ';  // Default pattern to mimic original behavior
            //     // TODO: set pattern to second arg if not
            //     // You Need to find a way to add another argument
            //     // if (arguments.size() > 1)
            //     //     pattern = checkAndGetColumn<ColumnFixedString>(column.get());
            //     DB::FunctionTrimImpl<typename Impl::Mode>::vector(col->getChars(), col->getOffsets(), col_res->getChars(), col_res->getOffsets(), input_rows_count, pattern);
            // }
            // else
            Impl::vector(col->getChars(), col->getOffsets(), col_res->getChars(), col_res->getOffsets(), input_rows_count);
            return col_res;
        }
        else if (const ColumnFixedString * col_fixed = checkAndGetColumn<ColumnFixedString>(column.get()))
        {
            auto col_res = ColumnFixedString::create(col_fixed->getN());
            Impl::vectorFixed(col_fixed->getChars(), col_fixed->getN(), col_res->getChars(), input_rows_count);
            return col_res;
        }
        else
            throw Exception(ErrorCodes::ILLEGAL_COLUMN, "Illegal column {} of argument of function {}",
                arguments[0].column->getName(), getName());
    }
};

}
